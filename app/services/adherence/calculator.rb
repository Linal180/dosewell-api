module Adherence
  class Calculator
    def self.call(patient:, now: Time.current)
      scope = patient.doses.merge(Dose.counts_toward_adherence).where(scheduled_at: ..now)
      counts = scope.group("doses.status").count
      taken = counts["taken"] || 0
      missed = counts["missed"] || 0
      scheduled = counts["scheduled"] || 0
      total = taken + missed + scheduled
      percentage = total.zero? ? nil : ((taken.to_f / total) * 100).round(1)

      {
        patient_id: patient.id,
        total:,
        taken:,
        missed:,
        scheduled:,
        percentage:,
        courses: courses_for(scope)
      }
    end

    def self.courses_for(scope)
      raw = scope.group("doses.prescription_id", "doses.status").count
      prescriptions = Prescription.where(id: raw.keys.map(&:first).uniq).includes(:medication).order(:id)
      prescriptions.map do |prescription|
        taken = raw[[prescription.id, "taken"]] || 0
        missed = raw[[prescription.id, "missed"]] || 0
        scheduled = raw[[prescription.id, "scheduled"]] || 0
        total = taken + missed + scheduled
        {
          prescription_id: prescription.id,
          medication: "#{prescription.medication.name} #{prescription.medication.strength}",
          total:,
          taken:,
          missed:,
          scheduled:,
          percentage: total.zero? ? nil : ((taken.to_f / total) * 100).round(1)
        }
      end
    end
  end
end
