module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate!
    attr_reader :current_user
  end

  private

  def authenticate!
    token = request.authorization.to_s.delete_prefix("Bearer ").strip
    @current_user = Auth::Token.user_from(token)
    render json: { error: "Unauthorized" }, status: :unauthorized if @current_user.blank?
  end

  def require_role!(*roles)
    return if roles.include?(current_user.role)

    render json: { error: "Forbidden" }, status: :forbidden
  end
end
