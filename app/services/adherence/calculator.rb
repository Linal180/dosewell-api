module Adherence
  class Calculator
    def self.call(patient:, now: Time.current)
      scope = patient.doses.where(scheduled_at: ..now)
      total = scope.count
      taken = scope.where(status: "taken").count
      missed = scope.where(status: "missed").count
      scheduled = scope.where(status: "scheduled").count
      percentage = total.zero? ? nil : ((taken.to_f / total) * 100).round(1)

      { patient_id: patient.id, total:, taken:, missed:, scheduled:, percentage: }
    end
  end
end
