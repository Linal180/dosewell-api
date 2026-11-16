module Api
  module V1
    class AuditLogsController < ApplicationController
      def index
        page, pagination = paginate(visible.order(created_at: :desc))
        render json: { audit_logs: page.includes(:actor).map(&:as_api), pagination: }
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
