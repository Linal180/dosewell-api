module Auth
  class Token
    PURPOSE = :api

    def self.issue(user)
      Rails.application.message_verifier(:api_token).generate(
        { "user_id" => user.id },
        expires_in: 24.hours,
        purpose: PURPOSE
      )
    end

    def self.user_from(token)
      return if token.blank?

      data = Rails.application.message_verifier(:api_token).verified(token, purpose: PURPOSE)
      return if data.blank?

      User.find_by(id: data["user_id"])
    end
  end
end
