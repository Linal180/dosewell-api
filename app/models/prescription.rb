class Prescription < ApplicationRecord
  include KnownTimezone

  FREQUENCIES = %w[once_daily twice_daily three_times_daily every_n_hours].freeze
  DAILY_TIMES = { "once_daily" => 1, "twice_daily" => 2, "three_times_daily" => 3 }.freeze
  STATUSES = %w[active cancelled].freeze
  UNITS = %w[tablet capsule ml mg mcg puff].freeze
  TIME_PATTERN = /\A(?:[01]\d|2[0-3]):[0-5]\d\z/

  belongs_to :patient, class_name: "User"
  belongs_to :doctor, class_name: "User"
  belongs_to :medication
  has_many :doses, dependent: :restrict_with_error, inverse_of: :prescription

  validates :dose_quantity, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :dose_unit, inclusion: { in: UNITS }
  validates :frequency, inclusion: { in: FREQUENCIES }
  validates :duration_days, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 365 }
  validates :start_date, :timezone, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :interval_hours, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 24 }, allow_nil: true
  validate :roles_match
  validate :schedule_shape
  validate :start_date_in_range

  scope :active, -> { where(status: "active") }
  scope :overlapping, ->(start_on, end_on) {
    where("start_date < ? AND (start_date + duration_days) > ?", end_on, start_on)
  }

  def end_date
    start_date + duration_days
  end

  def as_api(include_doses: false)
    payload = {
      id:,
      patient_id:,
      doctor_id:,
      medication_id:,
      dose_quantity: dose_quantity.to_s("F"),
      dose_unit:,
      frequency:,
      interval_hours:,
      times_of_day:,
      duration_days:,
      start_date: start_date.to_s,
      end_date: end_date.to_s,
      timezone:,
      status:,
      warnings:,
      warning_acknowledged:,
      medication: medication.as_api,
      patient: { id: patient.id, name: patient.name },
      doctor: { id: doctor.id, name: doctor.name },
      dose_count: doses.size
    }
    payload[:doses] = doses.sort_by(&:scheduled_at).map(&:as_api) if include_doses
    payload
  end

  private

  def roles_match
    errors.add(:patient, "must have the patient role") if patient.present? && !patient.patient?
    errors.add(:doctor, "must have the doctor role") if doctor.present? && !doctor.doctor?
  end

  def schedule_shape
    unless times_of_day.is_a?(Array) && times_of_day.all? { |value| value.is_a?(String) && TIME_PATTERN.match?(value) }
      errors.add(:times_of_day, "must be a list of HH:MM values")
      return
    end

    errors.add(:times_of_day, "must be unique") if times_of_day.uniq.length != times_of_day.length

    expected = DAILY_TIMES[frequency]
    if expected && times_of_day.length != expected
      errors.add(:times_of_day, "must include #{expected} #{'time'.pluralize(expected)}")
    elsif frequency == "every_n_hours" && times_of_day.length != 1
      errors.add(:times_of_day, "must include the first dose time")
    end

    if frequency == "every_n_hours"
      errors.add(:interval_hours, "must be between 1 and 24") if interval_hours.blank?
    elsif interval_hours.present?
      errors.add(:interval_hours, "is only allowed for every_n_hours")
    end
  end

  def start_date_in_range
    return if start_date.blank? || timezone.blank?
    return if errors[:timezone].any?

    today = TZInfo::Timezone.get(timezone).now.to_date
    if start_date < today - 7
      errors.add(:start_date, "cannot be more than 7 days ago")
    elsif start_date > today + 365
      errors.add(:start_date, "cannot be more than 365 days ahead")
    end
  end
end
