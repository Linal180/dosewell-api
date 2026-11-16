require "test_helper"

class DosesTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 6, 1, 15, 0, 0) do
      post "/api/v1/prescriptions",
        params: { prescription: prescription_params },
        headers: auth_header(:maya),
        as: :json
    end
    @doses = json_body.dig("prescription", "doses")
  end

  test "the patient records a due dose and adherence counts unmarked past doses" do
    travel_to Time.utc(2026, 6, 1, 15, 0, 0) do
      get "/api/v1/adherence", headers: auth_header(:sam)
      assert_equal 0.0, json_body.dig("adherence", "percentage")
      assert_equal 1, json_body.dig("adherence", "scheduled")

      patch "/api/v1/doses/#{@doses.first["id"]}",
        params: { dose: { status: "taken" } },
        headers: auth_header(:sam),
        as: :json
      assert_response :success
      assert_equal "taken", json_body.dig("dose", "status")

      get "/api/v1/adherence", headers: auth_header(:sam)
      assert_equal 100.0, json_body.dig("adherence", "percentage")
      assert_equal 1, AuditLog.where(action: "dose.recorded").count
    end
  end

  test "future doses, repeat marks, and other roles are rejected" do
    travel_to Time.utc(2026, 6, 1, 15, 0, 0) do
      assert_equal true, @doses.first["due"]
      assert_equal false, @doses.second["due"]

      patch "/api/v1/doses/#{@doses.second["id"]}",
        params: { dose: { status: "taken" } },
        headers: auth_header(:sam),
        as: :json
      assert_response :unprocessable_entity
      assert_match "Future", json_body["error"]

      patch "/api/v1/doses/#{@doses.first["id"]}",
        params: { dose: { status: "taken" } },
        headers: auth_header(:sam),
        as: :json
      assert_response :success

      patch "/api/v1/doses/#{@doses.first["id"]}",
        params: { dose: { status: "taken" } },
        headers: auth_header(:sam),
        as: :json
      assert_response :unprocessable_entity

      patch "/api/v1/doses/#{@doses.first["id"]}",
        params: { dose: { status: "missed" } },
        headers: auth_header(:sam),
        as: :json
      assert_response :success
      assert_equal ["taken", "missed"], AuditLog.order(:id).last.change_set["status"]

      patch "/api/v1/doses/#{@doses.first["id"]}",
        params: { dose: { status: "skipped" } },
        headers: auth_header(:sam),
        as: :json
      assert_response :unprocessable_entity

      patch "/api/v1/doses/#{@doses.first["id"]}",
        params: { dose: { status: "missed" } },
        headers: auth_header(:maya),
        as: :json
      assert_response :forbidden

      patch "/api/v1/doses/#{@doses.first["id"]}",
        params: { dose: { status: "missed" } },
        headers: auth_header(:priya),
        as: :json
      assert_response :forbidden
    end
  end

  test "a pharmacist can read adherence and the audit log" do
    get "/api/v1/adherence?patient_id=#{users(:sam).id}", headers: auth_header(:priya)
    assert_response :success

    get "/api/v1/adherence", headers: auth_header(:priya)
    assert_response :bad_request

    get "/api/v1/adherence?patient_id=#{users(:sam).id}", headers: auth_header(:ava)
    assert_response :forbidden

    get "/api/v1/audit_logs", headers: auth_header(:priya)
    assert_response :success
    assert json_body["audit_logs"].any? { |log| log["action"] == "prescription.created" }

    get "/api/v1/audit_logs", headers: auth_header(:ava)
    assert_response :success
    assert_empty json_body["audit_logs"]
  end

  test "a bad date filter is rejected" do
    get "/api/v1/doses?from=03-08-2026", headers: auth_header(:sam)
    assert_response :unprocessable_entity
  end

  private

  def prescription_params
    {
      patient_id: users(:sam).id,
      medication_id: medications(:metformin).id,
      dose_quantity: 1,
      dose_unit: "tablet",
      frequency: "once_daily",
      times_of_day: ["08:00"],
      duration_days: 7,
      start_date: "2026-06-01",
      timezone: "America/New_York",
      acknowledge_warnings: false
    }
  end
end
