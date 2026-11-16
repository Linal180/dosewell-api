module Schedules
  class Generator
    def self.call(prescription)
      new(prescription).call
    end

    def initialize(prescription)
      @prescription = prescription
      @zone = TZInfo::Timezone.get(prescription.timezone)
    end

    def call
      @prescription.frequency == "every_n_hours" ? interval_doses : wall_clock_doses
    end

    private

    def wall_clock_doses
      @prescription.duration_days.times.flat_map do |offset|
        date = @prescription.start_date + offset
        @prescription.times_of_day.sort.map do |clock|
          hour, minute = split(clock)
          instant, adjusted = resolve(date, hour, minute)
          entry(instant, adjusted)
        end
      end
    end

    def interval_doses
      hour, minute = split(@prescription.times_of_day.first)
      start_instant, start_adjusted = resolve(@prescription.start_date, hour, minute)
      finish_instant, = resolve(@prescription.start_date + @prescription.duration_days, hour, minute)
      cursor = start_instant.to_time
      finish = finish_instant.to_time
      first = true
      doses = []

      while cursor < finish
        doses << entry(cursor, first && start_adjusted)
        first = false
        cursor += @prescription.interval_hours.hours
      end

      doses
    end

    # `true` keeps the earlier occurrence when a wall clock time happens twice.
    def resolve(date, hour, minute)
      [local_time(date, hour, minute), false]
    rescue TZInfo::PeriodNotFound
      shifted_date, shifted_hour, shifted_minute = shift_through_gap(date, hour, minute)
      [local_time(shifted_date, shifted_hour, shifted_minute), true]
    end

    def local_time(date, hour, minute)
      @zone.local_time(date.year, date.month, date.day, hour, minute, 0, 0, true)
    end

    def shift_through_gap(date, hour, minute)
      total = hour * 60 + minute + gap_minutes(date)
      day_offset, minutes = total.divmod(24 * 60)
      [date + day_offset, minutes / 60, minutes % 60]
    end

    def gap_minutes(date)
      from = Time.utc(date.year, date.month, date.day) - 2.days
      to = Time.utc(date.year, date.month, date.day) + 2.days
      transition = @zone.transitions_up_to(to, from).find do |item|
        item.offset.utc_total_offset > item.previous_offset.utc_total_offset &&
          civil_date(item.at.to_time) == date
      end
      raise UnresolvableTime, "No daylight-saving gap for #{date} in #{@prescription.timezone}" unless transition

      (transition.offset.utc_total_offset - transition.previous_offset.utc_total_offset) / 60
    end

    def entry(instant, adjusted)
      time = instant.to_time.utc
      local = @zone.to_local(time)
      {
        scheduled_at: time,
        local_date: Date.new(local.year, local.month, local.day),
        local_time: format("%02d:%02d", local.hour, local.min),
        dst_adjusted: adjusted
      }
    end

    def civil_date(time)
      local = @zone.to_local(time)
      Date.new(local.year, local.month, local.day)
    end

    def split(clock)
      clock.split(":").map(&:to_i)
    end
  end
end
