module Prescriptions
  class Creator
    ATTRIBUTES = %i[
      dose_quantity dose_unit frequency interval_hours times_of_day
      duration_days start_date timezone
    ].freeze

    def self.call(doctor:, params:)
      new(doctor:, params:).call
    end

    def initialize(doctor:, params:)
      @doctor = doctor
      @params = params.to_h.symbolize_keys
    end

    def call
      prescription = build_prescription
      return invalid(prescription) unless prescription.valid?

      code = nil
      blocked = []
      warnings = []
      saved = nil

      prescription.patient.with_lock do
        safety = SafetyCheck.call(
          patient: prescription.patient,
          medication: prescription.medication,
          start_date: prescription.start_date,
          duration_days: prescription.duration_days
        )
        blocked = safety.blocked
        warnings = safety.warnings

        if safety.blocked?
          code = "blocked"
          next
        end

        if safety.needs_acknowledgement? && @params[:acknowledge_warnings] != true
          code = "acknowledgement_required"
          next
        end

        prescription.warnings = warnings
        prescription.warning_acknowledged = warnings.any? && @params[:acknowledge_warnings] == true
        prescription.save!

        doses = Schedules::Generator.call(prescription)
        if doses.empty?
          code = "invalid"
          prescription.errors.add(:base, "Schedule produced no doses")
          raise ActiveRecord::Rollback
        elsif doses.size > Schedules::Generator::MAX_DOSES
          code = "invalid"
          prescription.errors.add(:base, "Schedule has too many doses")
          raise ActiveRecord::Rollback
        elsif doses.map { |dose| dose[:scheduled_at].to_i }.uniq.size != doses.size
          code = "invalid"
          prescription.errors.add(:base, "Those times land on the same instant after a daylight-saving change")
          raise ActiveRecord::Rollback
        end

        now = Time.current
        Dose.insert_all!(doses.map { |attrs|
          attrs.merge(
            prescription_id: prescription.id,
            patient_id: prescription.patient_id,
            status: "scheduled",
            created_at: now,
            updated_at: now
          )
        })
        Audit::Recorder.call(
          actor: @doctor,
          action: "prescription.created",
          record: prescription,
          summary: "#{@doctor.name} prescribed #{prescription.medication.name} #{prescription.medication.strength} to #{prescription.patient.name}",
          change_set: {
            "patient_id" => prescription.patient_id,
            "medication_id" => prescription.medication_id,
            "frequency" => prescription.frequency,
            "duration_days" => prescription.duration_days,
            "start_date" => prescription.start_date.to_s,
            "timezone" => prescription.timezone,
            "warnings" => warnings
          }
        )
        saved = prescription
      end

      return Result.new(ok: true, code: "created", prescription: saved.reload, warnings:) if saved

      Result.new(ok: false, code: code || "invalid", prescription:, blocked:, warnings:)
    rescue Schedules::UnresolvableTime => error
      prescription.errors.add(:base, error.message)
      invalid(prescription)
    rescue ActiveRecord::RecordNotUnique
      prescription.errors.add(:base, "Those times land on the same instant after a daylight-saving change")
      invalid(prescription)
    end

    private

    def build_prescription
      prescription = Prescription.new(@params.slice(*ATTRIBUTES))
      prescription.doctor = @doctor
      prescription.status = "active"
      prescription.warnings = []
      prescription.warning_acknowledged = false
      prescription.patient = User.find_by(id: @params[:patient_id])
      prescription.medication = Medication.find_by(id: @params[:medication_id])
      prescription
    end

    def invalid(prescription)
      Result.new(ok: false, code: "invalid", prescription:)
    end
  end
end
