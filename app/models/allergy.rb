class Allergy < ApplicationRecord
  belongs_to :patient, class_name: "User"

  normalizes :ingredient, with: ->(value) { value.strip.downcase }

  validates :ingredient, presence: true, uniqueness: { scope: :patient_id, case_sensitive: false }
  validate :patient_has_patient_role

  def as_api
    { id:, ingredient: }
  end

  private

  def patient_has_patient_role
    return if patient.blank?
    errors.add(:patient, "must have the patient role") unless patient.patient?
  end
end
