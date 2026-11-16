module Authenticatable
  extend ActiveSupport::Concern

  WRITE_METHODS = %w[POST PUT PATCH DELETE].freeze

  included do
    class_attribute :write_roles, instance_accessor: false, default: {}
    before_action :authenticate!
    before_action :enforce_write_role
    attr_reader :current_user
  end

  class_methods do
    def allow_writes_for(*roles, only:)
      allowed = roles.map(&:to_s)
      assigned = write_roles.dup
      Array(only).each { |action| assigned[action.to_s] = allowed }
      self.write_roles = assigned
    end
  end

  private

  def authenticate!
    token = request.authorization.to_s.delete_prefix("Bearer ").strip
    @current_user = Auth::Token.user_from(token)
    render json: { error: "Unauthorized" }, status: :unauthorized if @current_user.blank?
  end

  def enforce_write_role
    return unless WRITE_METHODS.include?(request.method)
    return if self.class.write_roles[action_name]&.include?(current_user&.role)

    render json: { error: "Forbidden" }, status: :forbidden
  end
end
