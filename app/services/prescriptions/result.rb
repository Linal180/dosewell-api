module Prescriptions
  class Result
    attr_reader :prescription, :code, :blocked, :warnings

    def initialize(ok:, prescription:, code:, blocked: [], warnings: [])
      @ok = ok
      @prescription = prescription
      @code = code
      @blocked = blocked
      @warnings = warnings
    end

    def ok? = @ok
  end
end
