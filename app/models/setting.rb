class Setting < ApplicationRecord
  encrypts :gmail_app_password

  validates :reminder_days_before, numericality: { in: 1..14 }
  validates :reminder_hour, numericality: { in: 0..23 }

  def self.current
    first || create!
  end

  def mail_configured?
    gmail_address.present? && gmail_app_password.present?
  end

  def from_header
    name = [ committee_name, settlement_name ].compact_blank.join(" – ")
    name.present? ? %("#{name}" <#{gmail_address}>) : gmail_address
  end

  def smtp_settings
    { address: "smtp.gmail.com", port: 587, domain: "gmail.com", user_name: gmail_address,
      password: gmail_app_password.to_s.delete(" "), authentication: :plain, enable_starttls_auto: true }
  end

  def title
    [ committee_name, settlement_name ].compact_blank.join(" ")
  end
end
