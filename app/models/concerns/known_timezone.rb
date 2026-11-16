module KnownTimezone
  extend ActiveSupport::Concern

  included do
    validate :timezone_must_be_known
  end

  private

  def timezone_must_be_known
    return if timezone.blank?

    TZInfo::Timezone.get(timezone)
  rescue TZInfo::InvalidTimezoneIdentifier
    errors.add(:timezone, "is not a known IANA timezone")
  end
end
