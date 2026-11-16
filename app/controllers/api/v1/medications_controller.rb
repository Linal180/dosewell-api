module Api
  module V1
    class MedicationsController < ApplicationController
      def index
        query = params[:q].to_s.strip
        return render json: { error: "Search query is too long" }, status: :unprocessable_entity if query.length > 80

        medications = Medication.order(:name)
        if query.present?
          like = "%#{Medication.sanitize_sql_like(query)}%"
          medications = medications.where("name ILIKE :like OR generic_name ILIKE :like OR ingredient ILIKE :like", like:)
        end

        render json: { medications: medications.limit(20).map(&:as_api) }
      end
    end
  end
end
