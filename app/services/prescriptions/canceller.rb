module Prescriptions
  class Canceller
    def self.call(prescription:, doctor:)
      new(prescription:, doctor:).call
    end

    def initialize(prescription:, doctor:)
      @prescription = prescription
      @doctor = doctor
    end

    def call
      removed = 0
      cancelled = false

      @prescription.patient.with_lock do
        @prescription.lock!
        if @prescription.status != "active"
          next
        end

        removed = @prescription.doses.where(status: "scheduled").where("scheduled_at > ?", Time.current).delete_all
        @prescription.update!(status: "cancelled")
        Audit::Recorder.call(
          actor: @doctor,
          action: "prescription.cancelled",
          record: @prescription,
          summary: "#{@doctor.name} cancelled #{@prescription.medication.name} #{@prescription.medication.strength} for #{@prescription.patient.name}",
          change_set: { "status" => %w[active cancelled], "future_doses_removed" => removed }
        )
        cancelled = true
      end

      if cancelled
        Result.new(ok: true, code: "cancelled", prescription: @prescription.reload)
      else
        @prescription.errors.add(:status, "is not active")
        Result.new(ok: false, code: "invalid", prescription: @prescription)
      end
    end
  end
end
