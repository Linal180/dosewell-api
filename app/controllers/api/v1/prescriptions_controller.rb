module Api
  module V1
    class PrescriptionsController < ApplicationController
      before_action -> { require_role!("doctor") }, only: :create

      def index
        prescriptions = visible.includes(:medication, :patient, :doctor).order(start_date: :desc, id: :desc)
        if params[:patient_id].present?
          if current_user.patient? && params[:patient_id].to_i != current_user.id
            return render json: { error: "Forbidden" }, status: :forbidden
          end
          prescriptions = prescriptions.where(patient_id: params[:patient_id]) unless current_user.patient?
        end

        render json: { prescriptions: prescriptions.map(&:as_api) }
      end

      def show
        prescription = Prescription.includes(:medication, :patient, :doctor, :doses).find(params[:id])
        if current_user.patient? && prescription.patient_id != current_user.id
          return render json: { error: "Forbidden" }, status: :forbidden
        end

        render json: { prescription: prescription.as_api(include_doses: true) }
      end

      def create
        result = Prescriptions::Creator.call(doctor: current_user, params: prescription_params)
        if result.ok?
          render json: { prescription: result.prescription.as_api(include_doses: true) }, status: :created
        elsif result.code == "invalid"
          render json: { error: "Invalid prescription", code: "invalid", details: result.prescription.errors.to_hash }, status: :unprocessable_entity
        else
          message = result.code == "blocked" ? "Prescription blocked" : "Acknowledgement required"
          render json: {
            error: message,
            code: result.code,
            blocked: result.blocked,
            warnings: result.warnings
          }, status: :unprocessable_entity
        end
      end

      private

      def visible
        current_user.patient? ? current_user.prescriptions_as_patient : Prescription.all
      end

      def prescription_params
        params.require(:prescription).permit(
          :patient_id, :medication_id, :dose_quantity, :dose_unit, :frequency,
          :interval_hours, :duration_days, :start_date, :timezone, :acknowledge_warnings,
          times_of_day: []
        )
      end
    end
  end
end
