module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate!, only: :login

      def login
        user = User.find_by(email: params[:email].to_s.strip.downcase)
        if user&.authenticate(params[:password].to_s)
          render json: { token: Auth::Token.issue(user), user: user.as_api }
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end

      def me
        render json: { user: current_user.as_api }
      end
    end
  end
end
