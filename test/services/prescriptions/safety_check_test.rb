require "test_helper"

class Prescriptions::SafetyCheckTest < ActiveSupport::TestCase
  setup do
    travel_to Time.utc(2026, 6, 1, 15, 0, 0)
  end

  test "an allergy blocks prescribing" do
    result = check(:ava, :metformin)

    assert_not result.blocked?
    allergy = check(:ava, :ibuprofen)
    assert allergy.blocked?
    assert_equal "allergy", allergy.blocked.first["type"]
  end

  test "a major interaction blocks from either side of the pair" do
    prescribe(:sam, :warfarin)
    left = check(:sam, :aspirin)
    assert_equal ["major"], left.blocked.map { |item| item["severity"] }

    Prescription.delete_all
    prescribe(:sam, :aspirin)
    right = check(:sam, :warfarin)
    assert_equal "interaction", right.blocked.first["type"]
    assert_equal "major", right.blocked.first["severity"]
  end

  test "a moderate interaction warns and a minor interaction does not require acknowledgement" do
    prescribe(:sam, :lisinopril)
    moderate = check(:sam, :ibuprofen)
    assert_not moderate.blocked?
    assert moderate.needs_acknowledgement?
    assert_equal "moderate", moderate.warnings.first["severity"]

    Prescription.delete_all
    prescribe(:sam, :atorvastatin)
    minor = check(:sam, :omeprazole)
    assert_not minor.blocked?
    assert_not minor.needs_acknowledgement?
    assert_equal "minor", minor.warnings.first["severity"]
  end

  test "courses that only touch at the boundary do not interact" do
    prescribe(:sam, :warfarin, start_date: Date.new(2026, 6, 1), duration_days: 7)
    result = check(:sam, :aspirin, start_date: Date.new(2026, 6, 8), duration_days: 7)

    assert_not result.blocked?
    assert_empty result.warnings
  end

  test "a cancelled course does not count as an interaction" do
    prescribe(:sam, :warfarin, status: "cancelled")
    result = check(:sam, :aspirin)

    assert_not result.blocked?
  end

  test "an overlapping course of the same medication is a duplicate" do
    prescribe(:sam, :metformin)
    result = check(:sam, :metformin)

    assert_equal "duplicate", result.blocked.first["type"]
  end

  private

  def check(patient, medication, start_date: Date.new(2026, 6, 1), duration_days: 7)
    Prescriptions::SafetyCheck.call(
      patient: users(patient),
      medication: medications(medication),
      start_date:,
      duration_days:
    )
  end

  def prescribe(patient, medication, **overrides)
    Prescription.create!({
      patient: users(patient),
      doctor: users(:maya),
      medication: medications(medication),
      dose_quantity: 1,
      dose_unit: "tablet",
      frequency: "once_daily",
      times_of_day: ["08:00"],
      duration_days: 7,
      start_date: Date.new(2026, 6, 1),
      timezone: "America/New_York",
      status: "active",
      warnings: [],
      warning_acknowledged: false
    }.merge(overrides))
  end
end
