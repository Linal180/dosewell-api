module Api
  module V1
    class AuditLogsController < ApplicationController
      def index
        logs = visible.order(created_at: :desc).limit(100).includes(:actor)
        render json: { audit_logs: logs.map(&:as_api) }
      end

      private

      def visible
        return AuditLog.all unless current_user.patient?

        dose_ids = current_user.doses.select(:id)
        prescription_ids = current_user.prescriptions_as_patient.select(:id)
        AuditLog.where(auditable_type: "Dose", auditable_id: dose_ids)
          .or(AuditLog.where(auditable_type: "Prescription", auditable_id: prescription_ids))
      end
    end
  end
end
