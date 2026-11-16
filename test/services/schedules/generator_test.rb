require "test_helper"

class Schedules::GeneratorTest < ActiveSupport::TestCase
  Plan = Struct.new(:timezone, :frequency, :times_of_day, :duration_days, :start_date, :interval_hours, keyword_init: true)

  test "daily doses keep local wall time across the spring-forward change" do
    doses = generate(start_date: Date.new(2026, 3, 6), duration_days: 4)

    assert_equal ["08:00", "08:00", "08:00", "08:00"], doses.map { |dose| dose[:local_time] }
    assert_equal [false, false, false, false], doses.map { |dose| dose[:dst_adjusted] }
    assert_equal "2026-03-07 13:00:00 UTC", stamp(doses[1])
    assert_equal "2026-03-08 12:00:00 UTC", stamp(doses[2])
  end

  test "a wall time inside the spring-forward gap is shifted by the gap and flagged" do
    doses = generate(start_date: Date.new(2026, 3, 7), duration_days: 3, times_of_day: ["02:30"])

    assert_equal ["02:30", "03:30", "02:30"], doses.map { |dose| dose[:local_time] }
    assert_equal [false, true, false], doses.map { |dose| dose[:dst_adjusted] }
    assert_equal "2026-03-07 07:30:00 UTC", stamp(doses[0])
    assert_equal "2026-03-08 07:30:00 UTC", stamp(doses[1])
    assert_equal "2026-03-09 06:30:00 UTC", stamp(doses[2])
  end

  test "an ambiguous fall-back time is scheduled once at the first occurrence" do
    doses = generate(start_date: Date.new(2026, 10, 31), duration_days: 3, times_of_day: ["01:30"])

    assert_equal 3, doses.length
    assert_equal ["01:30", "01:30", "01:30"], doses.map { |dose| dose[:local_time] }
    assert_equal false, doses[1][:dst_adjusted]
    assert_equal "2026-11-01 05:30:00 UTC", stamp(doses[1])
    assert_equal "2026-11-02 06:30:00 UTC", stamp(doses[2])
  end

  test "interval doses stay eight absolute hours apart across the spring-forward change" do
    doses = generate(
      start_date: Date.new(2026, 3, 7),
      duration_days: 2,
      frequency: "every_n_hours",
      interval_hours: 8,
      times_of_day: ["22:00"]
    )

    assert_equal 6, doses.length
    assert_equal "2026-03-08 03:00:00 UTC", stamp(doses[0])
    assert_equal "07:00", doses[1][:local_time]
    assert_equal Date.new(2026, 3, 8), doses[1][:local_date]
    doses.each_cons(2) do |earlier, later|
      assert_equal 8.hours.to_i, (later[:scheduled_at] - earlier[:scheduled_at]).to_i
    end
  end

  test "duration is an exclusive end so one daily day creates one dose" do
    doses = generate(start_date: Date.new(2026, 6, 1), duration_days: 1)

    assert_equal 1, doses.length
    assert_equal Date.new(2026, 6, 1), doses[0][:local_date]
  end

  test "twice daily doses cover both wall times on each calendar day" do
    doses = generate(start_date: Date.new(2026, 3, 8), duration_days: 2, frequency: "twice_daily", times_of_day: ["20:00", "08:00"])

    assert_equal 4, doses.length
    assert_equal ["08:00", "20:00", "08:00", "20:00"], doses.map { |dose| dose[:local_time] }
    assert_equal "2026-03-08 12:00:00 UTC", stamp(doses[0])
    assert_equal "2026-03-09 00:00:00 UTC", stamp(doses[1])
  end

  test "a zone without daylight saving does not move a 02:30 dose" do
    doses = generate(timezone: "America/Phoenix", start_date: Date.new(2026, 3, 8), times_of_day: ["02:30"])

    assert_equal "02:30", doses[0][:local_time]
    assert_equal false, doses[0][:dst_adjusted]
    assert_equal "2026-03-08 09:30:00 UTC", stamp(doses[0])
  end

  test "a European spring-forward gap is shifted using that zone" do
    doses = generate(timezone: "Europe/London", start_date: Date.new(2026, 3, 29), times_of_day: ["01:30"])

    assert_equal "02:30", doses[0][:local_time]
    assert_equal true, doses[0][:dst_adjusted]
    assert_equal "2026-03-29 01:30:00 UTC", stamp(doses[0])
  end

  private

  def generate(overrides = {})
    plan = Plan.new({
      timezone: "America/New_York",
      frequency: "once_daily",
      times_of_day: ["08:00"],
      duration_days: 1,
      start_date: Date.new(2026, 6, 1),
      interval_hours: nil
    }.merge(overrides))
    Schedules::Generator.call(plan)
  end

  def stamp(dose)
    dose[:scheduled_at].utc.strftime("%Y-%m-%d %H:%M:%S UTC")
  end
end
