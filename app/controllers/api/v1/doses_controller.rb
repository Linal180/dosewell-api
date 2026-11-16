module Api
  module V1
    class DosesController < ApplicationController
      allow_writes_for :patient, only: :update

      def index
        doses = visible.order(:scheduled_at)
        if params[:patient_id].present?
          if current_user.patient? && params[:patient_id].to_i != current_user.id
            return render json: { error: "Forbidden" }, status: :forbidden
          end
          doses = doses.where(patient_id: params[:patient_id]) unless current_user.patient?
        end
        doses = doses.where(prescription_id: params[:prescription_id]) if params[:prescription_id].present?
        doses = doses.where(local_date: date_bound(params[:from])..) if params[:from].present?
        doses = doses.where(local_date: ..date_bound(params[:to])) if params[:to].present?

        page, pagination = paginate(doses)
        render json: { doses: page.includes(prescription: :medication).map(&:as_api), pagination: }
      rescue Date::Error
        render json: { error: "Dates must be YYYY-MM-DD" }, status: :unprocessable_entity
      end

      def update
        dose = current_user.doses.find(params[:id])
        result = Doses::Recorder.call(dose:, actor: current_user, status: dose_params[:status])
        if result.ok?
          render json: { dose: result.dose.reload.as_api }
        else
          render json: { error: result.error, code: "invalid" }, status: :unprocessable_entity
        end
      end

      private

      def visible
        current_user.patient? ? current_user.doses : Dose.all
      end

      def dose_params
        params.require(:dose).permit(:status)
      end

      def date_bound(value)
        Date.iso8601(value.to_s)
      end
    end
  end
end
