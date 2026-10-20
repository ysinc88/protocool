class ApplicationMailer < ActionMailer::Base
  layout "mailer"

  private

  def setting = @setting ||= Setting.current

  def committee_mail(**opts)
    # Previews work before Gmail is configured; deliveries are gated on mail_configured? by callers.
    mail(from: setting.gmail_address.present? ? setting.from_header : "protocool@localhost", reply_to: setting.gmail_address,
         delivery_method_options: setting.smtp_settings, **opts)
  end
end
