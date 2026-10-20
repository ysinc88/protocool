class SendRemindersJob < ApplicationJob
  queue_as :mail

  def perform(meeting_id = nil)
    setting = Setting.current
    return unless setting.mail_configured?
    meetings = meeting_id ? Meeting.where(id: meeting_id) : Meeting.where(reminder_sent_at: nil, scheduled_at: Time.current..15.days.from_now)
    meetings.each do |meeting|
      next unless meeting_id || meeting.reminder_due?
      Member.active.each { |m| CommitteeMailer.reminder(meeting, m).deliver_now }
      meeting.update!(reminder_sent_at: Time.current)
    end
  end
end
