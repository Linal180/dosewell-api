module Audit
  class Recorder
    def self.call(actor:, action:, record:, summary:, change_set: {})
      AuditLog.create!(
        actor:,
        action:,
        auditable_type: record.class.name,
        auditable_id: record.id,
        summary:,
        change_set:
      )
    end
  end
end
