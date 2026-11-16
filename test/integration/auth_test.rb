require "test_helper"

class AuthTest < ActionDispatch::IntegrationTest
  test "login returns a token and me reads it back" do
    post "/api/v1/auth/login", params: { email: "Maya.Chen@dosewell.test", password: "Password1!" }, as: :json

    assert_response :success
    assert json_body["token"].present?
    assert_equal "doctor", json_body.dig("user", "role")

    get "/api/v1/auth/me", headers: { "Authorization" => "Bearer #{json_body["token"]}" }
    assert_response :success
    assert_equal "Maya Chen", json_body.dig("user", "name")
  end

  test "bad password and missing token are unauthorized" do
    post "/api/v1/auth/login", params: { email: "maya.chen@dosewell.test", password: "nope" }, as: :json
    assert_response :unauthorized

    get "/api/v1/auth/me"
    assert_response :unauthorized
  end

  test "a patient only sees their own record" do
    get "/api/v1/patients", headers: auth_header(:ava)
    assert_response :success
    assert_equal ["Ava Shah"], json_body["patients"].map { |patient| patient["name"] }

    get "/api/v1/patients/#{users(:sam).id}", headers: auth_header(:ava)
    assert_response :not_found
  end

  test "a pharmacist can list patients and cannot receive a doctor through that endpoint" do
    get "/api/v1/patients", headers: auth_header(:priya)
    assert_response :success
    assert_equal ["Ava Shah", "Sam Okonkwo"], json_body["patients"].map { |patient| patient["name"] }

    get "/api/v1/patients/#{users(:maya).id}", headers: auth_header(:priya)
    assert_response :not_found
  end
end
