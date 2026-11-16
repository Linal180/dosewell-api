class AuditLog < ApplicationRecord
  belongs_to :actor, class_name: "User"

  validates :action, :auditable_type, :auditable_id, :summary, presence: true

  def as_api
    {
      id:,
      action:,
      summary:,
      auditable_type:,
      auditable_id:,
      change_set:,
      created_at: created_at.iso8601,
      actor: { id: actor.id, name: actor.name, role: actor.role }
    }
  end
end
