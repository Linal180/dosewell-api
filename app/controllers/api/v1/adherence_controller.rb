module Api
  module V1
    class AdherenceController < ApplicationController
      def show
        patient = if current_user.patient?
          if params[:patient_id].present? && params[:patient_id].to_i != current_user.id
            return render json: { error: "Forbidden" }, status: :forbidden
          end
          current_user
        else
          return render json: { error: "patient_id is required" }, status: :bad_request if params[:patient_id].blank?

          User.patients.find(params[:patient_id])
        end

        render json: { adherence: Adherence::Calculator.call(patient:) }
      end
    end
  end
end
