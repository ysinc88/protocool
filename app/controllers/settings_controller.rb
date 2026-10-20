class SettingsController < ApplicationController
  def edit; end

  def update
    attrs = params.expect(setting: %i[committee_name settlement_name chair_name gmail_address gmail_app_password
                                      community_email reminder_days_before reminder_hour default_location])
    attrs.delete(:gmail_app_password) if attrs[:gmail_app_password].blank?
    if setting.update(attrs)
      redirect_to edit_settings_path, notice: "ההגדרות נשמרו"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def test_email
    CommitteeMailer.test_message(setting.gmail_address).deliver_now
    redirect_to edit_settings_path, notice: "מייל בדיקה נשלח ל-#{setting.gmail_address}"
  rescue => e
    redirect_to edit_settings_path, alert: "השליחה נכשלה: #{e.message}"
  end

  def poll_inbox
    n = InboxPoller.new.call
    redirect_back_or_to edit_settings_path, notice: "נבדקה תיבת הדואר: #{n} נושאים חדשים"
  rescue => e
    redirect_back_or_to edit_settings_path, alert: "בדיקת התיבה נכשלה: #{e.message}"
  end
end
