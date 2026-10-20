class Meeting < ApplicationRecord
  has_many :topic_suggestions, dependent: :destroy
  has_many :tasks, -> { order(:id) }, dependent: :destroy
  has_many :recordings, -> { order(:id) }, dependent: :destroy
  has_many :rsvps, dependent: :destroy

  def rsvp_for(member) = rsvps.find { |r| r.member_id == member.id }
  def attending_members = rsvps.select { |r| r.status == "yes" }.map(&:member)

  validates :scheduled_at, presence: true

  scope :upcoming, -> { where(scheduled_at: Time.current.beginning_of_day..).order(:scheduled_at) }
  scope :past, -> { where(scheduled_at: ...Time.current.beginning_of_day).order(scheduled_at: :desc) }

  # Ascii tag in the subject so replies can be matched over IMAP.
  def mail_tag = "[VC-#{id}]"

  def self.find_by_subject(subject)
    find_by(id: subject.to_s[/\[VC-(\d+)\]/, 1])
  end

  def previous
    Meeting.where(scheduled_at: ...scheduled_at).order(scheduled_at: :desc).first
  end

  def previous_with_protocol
    Meeting.where(scheduled_at: ...scheduled_at).where.not(summary: [ nil, "" ]).order(scheduled_at: :desc).first ||
      Meeting.where(scheduled_at: ...scheduled_at).where.not(protocol_text: [ nil, "" ]).order(scheduled_at: :desc).first
  end

  # A reminder that would fall on Shabbat goes out on Friday at the same hour instead.
  def reminder_due_at
    s = Setting.current
    date = scheduled_at.to_date - s.reminder_days_before
    date -= 1 if date.saturday? && Meeting.observe_shabbat?
    date.in_time_zone.change(hour: s.reminder_hour)
  end

  def reminder_due?
    reminder_sent_at.nil? && scheduled_at.future? && Time.current >= reminder_due_at && !Meeting.shabbat?
  end

  # Catch-up sends (machine was off, meeting set late) also wait out Shabbat:
  # Friday from 15:00 until Saturday 20:00.
  def self.shabbat?(t = Time.current)
    observe_shabbat? && ((t.friday? && t.hour >= 15) || (t.saturday? && t.hour < 20))
  end

  # Set PROTOCOOL_OBSERVE_SHABBAT=false to send reminders on Saturdays too.
  def self.observe_shabbat? = ENV.fetch("PROTOCOOL_OBSERVE_SHABBAT", "true") != "false"

  def held? = scheduled_at.past?
  def processing? = processing_status.in?(%w[queued running])
  def processed? = processed_at.present?

  def date_label
    I18n.l(scheduled_at, format: :meeting)
  end

  def transcript_text
    recordings.select(&:done?).map(&:transcript_text).join("\n\n")
  end
end
