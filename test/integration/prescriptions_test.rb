require "test_helper"

class PrescriptionsTest < ActionDispatch::IntegrationTest
  setup do
    @when = Time.utc(2026, 6, 1, 15, 0, 0)
  end

  test "a doctor prescription creates the schedule and an audit row" do
    travel_to @when do
      post_prescription(:sam, :metformin)
    end

    assert_response :created
    body = json_body["prescription"]
    assert_equal 7, body["doses"].length
    assert_equal "08:00", body["doses"].first["local_time"]
    assert_equal "America/New_York", body["doses"].first["timezone"]
    assert_equal 1, AuditLog.where(action: "prescription.created", auditable_id: body["id"]).count
  end

  test "the spring-forward gap is stored on the dose that cannot exist" do
    travel_to Time.utc(2026, 3, 6, 15, 0, 0) do
      post_prescription(:sam, :metformin, start_date: "2026-03-07", duration_days: 3, times_of_day: ["02:30"])
    end

    assert_response :created
    shifted = json_body.dig("prescription", "doses", 1)
    assert_equal "03:30", shifted["local_time"]
    assert_equal true, shifted["dst_adjusted"]
    assert_equal "2026-03-08T07:30:00Z", shifted["scheduled_at"]
  end

  test "patients and pharmacists cannot prescribe" do
    travel_to @when do
      assert_no_difference "Prescription.count" do
        post_prescription(:sam, :metformin, as: :ava)
        assert_response :forbidden
        post_prescription(:sam, :metformin, as: :priya)
        assert_response :forbidden
      end
    end
  end

  test "an allergy is blocked even when the warning is acknowledged" do
    travel_to @when do
      assert_no_difference "Prescription.count" do
        post_prescription(:ava, :ibuprofen, acknowledge_warnings: true)
      end
    end

    assert_response :unprocessable_entity
    assert_equal "blocked", json_body["code"]
    assert_equal "allergy", json_body["blocked"].first["type"]
    assert_equal 0, AuditLog.count
  end

  test "a major interaction is blocked and acknowledgement does not override it" do
    travel_to @when do
      post_prescription(:sam, :warfarin)
      assert_response :created
      assert_no_difference "Prescription.count" do
        post_prescription(:sam, :aspirin, acknowledge_warnings: true)
      end
    end

    assert_response :unprocessable_entity
    assert_equal "blocked", json_body["code"]
    assert_equal "major", json_body["blocked"].first["severity"]
  end

  test "a moderate interaction waits for acknowledgement and then stores the warning" do
    travel_to @when do
      post_prescription(:sam, :lisinopril)
      assert_no_difference "Prescription.count" do
        post_prescription(:sam, :ibuprofen)
      end
      assert_response :unprocessable_entity
      assert_equal "acknowledgement_required", json_body["code"]
      assert_equal "moderate", json_body["warnings"].first["severity"]

      post_prescription(:sam, :ibuprofen, acknowledge_warnings: true)
    end

    assert_response :created
    assert_equal true, json_body.dig("prescription", "warning_acknowledged")
    assert_equal "moderate", json_body.dig("prescription", "warnings", 0, "severity")
  end

  test "a minor interaction is stored without acknowledgement" do
    travel_to @when do
      post_prescription(:sam, :atorvastatin)
      post_prescription(:sam, :omeprazole)
    end

    assert_response :created
    assert_equal false, json_body.dig("prescription", "warning_acknowledged")
    assert_equal "minor", json_body.dig("prescription", "warnings", 0, "severity")
  end

  test "invalid schedule input is rejected" do
    cases = [
      { frequency: "daily" },
      { times_of_day: ["8:00"] },
      { times_of_day: ["08:00", "20:00"] },
      { duration_days: 0 },
      { timezone: "Not/AZone" },
      { interval_hours: 8 },
      { dose_unit: "spoon" },
      { frequency: "every_n_hours", times_of_day: ["06:00"] },
      { start_date: "2026-01-01" }
    ]

    travel_to @when do
      assert_no_difference "Prescription.count" do
        cases.each do |overrides|
          post_prescription(:sam, :metformin, **overrides)
          assert_response :unprocessable_entity, "expected #{overrides.inspect} to be rejected, got #{response.status} #{response.body}"
          assert_equal "invalid", json_body["code"]
        end
      end
    end
  end

  test "a patient cannot read another patient's prescription" do
    travel_to @when do
      post_prescription(:sam, :metformin)
    end
    id = json_body.dig("prescription", "id")

    get "/api/v1/prescriptions/#{id}", headers: auth_header(:ava)
    assert_response :forbidden

    get "/api/v1/prescriptions/#{id}", headers: auth_header(:priya)
    assert_response :success
  end

  private

  def post_prescription(patient, medication, as: :maya, **overrides)
    payload = {
      patient_id: users(patient).id,
      medication_id: medications(medication).id,
      dose_quantity: 1,
      dose_unit: "tablet",
      frequency: "once_daily",
      times_of_day: ["08:00"],
      duration_days: 7,
      start_date: "2026-06-01",
      timezone: "America/New_York",
      acknowledge_warnings: false
    }.merge(overrides)

    post "/api/v1/prescriptions",
      params: { prescription: payload },
      headers: auth_header(as),
      as: :json
  end
end
