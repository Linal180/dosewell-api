module Api
  module V1
    class PatientsController < ApplicationController
      def index
        patients = visible_patients.order(:name)
        render json: { patients: patients.map(&:as_api) }
      end

      def show
        patient = visible_patients.find(params[:id])
        render json: { patient: patient.as_api(detail: true) }
      end

      private

      def visible_patients
        current_user.patient? ? User.patients.where(id: current_user.id) : User.patients
      end
    end
  end
end
