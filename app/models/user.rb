class User < ApplicationRecord
  include KnownTimezone

  ROLES = %w[doctor patient pharmacist].freeze

  has_secure_password

  has_many :allergies, foreign_key: :patient_id, dependent: :destroy
  has_many :prescriptions_as_patient, class_name: "Prescription", foreign_key: :patient_id, dependent: :restrict_with_error
  has_many :prescriptions_as_doctor, class_name: "Prescription", foreign_key: :doctor_id, dependent: :restrict_with_error
  has_many :doses, foreign_key: :patient_id, dependent: :restrict_with_error

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :name, presence: true, length: { maximum: 80 }
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: ROLES }
  validates :timezone, presence: true

  scope :patients, -> { where(role: "patient") }

  def doctor? = role == "doctor"
  def patient? = role == "patient"
  def pharmacist? = role == "pharmacist"

  def as_api(detail: false)
    payload = { id:, email:, name:, role:, timezone: }
    return payload unless detail

    payload.merge(
      allergies: allergies.order(:ingredient).map(&:as_api),
      prescriptions: prescriptions_as_patient.includes(:medication, :doctor).order(start_date: :desc).map(&:as_api)
    )
  end
end
