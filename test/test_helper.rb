ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "bcrypt"

BCrypt::Engine.cost = 4

module ActiveSupport
  class TestCase
    parallelize(workers: 1)
    fixtures :all
  end
end

module ActionDispatch
  class IntegrationTest
    def json_body
      JSON.parse(response.body)
    end

    def auth_header(user)
      { "Authorization" => "Bearer #{Auth::Token.issue(users(user))}" }
    end
  end
end
