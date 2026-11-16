class Medication < ApplicationRecord
  FORMS = %w[tablet capsule inhaler liquid].freeze

  has_many :prescriptions, dependent: :restrict_with_error

  validates :name, :generic_name, :ingredient, :strength, presence: true
  validates :form, inclusion: { in: FORMS }
  validates :name, uniqueness: { scope: :strength, case_sensitive: false }

  normalizes :ingredient, with: ->(value) { value.strip.downcase }
  normalizes :name, :generic_name, :strength, with: ->(value) { value.strip }

  def as_api
    { id:, name:, generic_name:, ingredient:, strength:, form:, label: "#{name} #{strength}" }
  end
end
