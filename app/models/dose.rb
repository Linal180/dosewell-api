class Dose < ApplicationRecord
  STATUSES = %w[scheduled taken missed].freeze
  RECORDABLE = %w[taken missed].freeze

  belongs_to :prescription, inverse_of: :doses
  belongs_to :patient, class_name: "User"
  belongs_to :recorded_by, class_name: "User", optional: true

  validates :scheduled_at, :local_date, :local_time, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :local_time, format: { with: Prescription::TIME_PATTERN }
  validate :patient_matches_prescription

  def as_api
    {
      id:,
      prescription_id:,
      patient_id:,
      medication: {
        id: prescription.medication_id,
        name: prescription.medication.name,
        strength: prescription.medication.strength
      },
      dose_quantity: prescription.dose_quantity.to_s("F"),
      dose_unit: prescription.dose_unit,
      scheduled_at: scheduled_at.iso8601,
      local_date: local_date.to_s,
      local_time:,
      timezone: prescription.timezone,
      dst_adjusted:,
      due: scheduled_at <= Time.current,
      status:,
      recorded_at: recorded_at&.iso8601
    }
  end

  private

  def patient_matches_prescription
    return if prescription.blank? || patient_id.blank?
    errors.add(:patient, "must match the prescription") if patient_id != prescription.patient_id
  end
end
