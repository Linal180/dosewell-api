class ApplicationController < ActionController::API
  include Authenticatable

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActionController::ParameterMissing, with: :render_bad_request

  private

  def render_not_found
    render json: { error: "Not found" }, status: :not_found
  end

  def render_bad_request(error)
    render json: { error: error.message }, status: :bad_request
  end

  def paginate(scope)
    page = [params[:page].to_i, 1].max
    per = params[:per].to_i
    per = 50 if per <= 0
    per = 100 if per > 100
    total = scope.unscope(:order).count
    [scope.offset((page - 1) * per).limit(per), { page:, per:, total: }]
  end
end
