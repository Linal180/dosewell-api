class Interaction < ApplicationRecord
  SEVERITIES = %w[major moderate minor].freeze

  belongs_to :medication_a, class_name: "Medication"
  belongs_to :medication_b, class_name: "Medication"

  validates :severity, inclusion: { in: SEVERITIES }
  validates :description, presence: true, length: { maximum: 300 }
  validate :pair_must_be_two_medications

  before_validation :order_pair

  def self.between(left_id, right_id)
    low, high = [left_id, right_id].minmax
    find_by(medication_a_id: low, medication_b_id: high)
  end

  private

  def order_pair
    return if medication_a_id.blank? || medication_b_id.blank?
    return if medication_a_id < medication_b_id

    self.medication_a_id, self.medication_b_id = medication_b_id, medication_a_id
    association(:medication_a).reset
    association(:medication_b).reset
  end

  def pair_must_be_two_medications
    return if medication_a_id.blank? || medication_b_id.blank?
    errors.add(:medication_b, "must be a different medication") if medication_a_id == medication_b_id
  end
end
