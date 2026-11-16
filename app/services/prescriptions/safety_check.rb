module Prescriptions
  class SafetyCheck
    Result = Struct.new(:blocked, :warnings, keyword_init: true) do
      def blocked? = blocked.any?

      def needs_acknowledgement?
        blocked.empty? && warnings.any? { |warning| warning["severity"] == "moderate" }
      end
    end

    def self.call(patient:, medication:, start_date:, duration_days:)
      new(patient:, medication:, start_date:, duration_days:).call
    end

    def initialize(patient:, medication:, start_date:, duration_days:)
      @patient = patient
      @medication = medication
      @start_date = start_date
      @duration_days = duration_days
    end

    def call
      blocked = []
      warnings = []
      allergy = @patient.allergies.find_by("LOWER(ingredient) = ?", @medication.ingredient.to_s.downcase)

      if allergy
        blocked << item("allergy", "severe", "#{@patient.name} is allergic to #{@medication.ingredient}")
      end

      overlapping = @patient.prescriptions_as_patient.active.overlapping(@start_date, @start_date + @duration_days).includes(:medication)
      overlapping.each do |prescription|
        if prescription.medication_id == @medication.id
          blocked << item("duplicate", "major", "#{@patient.name} already has an active #{@medication.name} prescription covering these dates")
          next
        end

        interaction = Interaction.between(@medication.id, prescription.medication_id)
        next unless interaction

        entry = item(
          "interaction",
          interaction.severity,
          interaction.description,
          "medication_name" => prescription.medication.name
        )
        interaction.severity == "major" ? blocked << entry : warnings << entry
      end

      Result.new(blocked:, warnings:)
    end

    private

    def item(type, severity, message, extra = {})
      { "type" => type, "severity" => severity, "message" => message }.merge(extra)
    end
  end
end
