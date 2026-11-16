module Doses
  class Recorder
    Result = Struct.new(:ok, :dose, :error, keyword_init: true) do
      def ok? = ok
    end

    def self.call(dose:, actor:, status:)
      new(dose:, actor:, status:).call
    end

    def initialize(dose:, actor:, status:)
      @dose = dose
      @actor = actor
      @status = status
    end

    def call
      return Result.new(ok: false, dose: @dose, error: "Status must be taken or missed") unless Dose::RECORDABLE.include?(@status)

      @dose.with_lock do
        if @dose.scheduled_at > Time.current
          return Result.new(ok: false, dose: @dose, error: "Future doses cannot be recorded")
        end
        if @dose.status == @status
          return Result.new(ok: false, dose: @dose, error: "Dose is already #{@status}")
        end

        previous = @dose.status
        @dose.update!(status: @status, recorded_at: Time.current, recorded_by: @actor)
        Audit::Recorder.call(
          actor: @actor,
          action: "dose.recorded",
          record: @dose,
          summary: "#{@actor.name} marked the #{@dose.local_time} dose on #{@dose.local_date} as #{@status}",
          change_set: { "status" => [previous, @status] }
        )
      end

      Result.new(ok: true, dose: @dose)
    end
  end
end
