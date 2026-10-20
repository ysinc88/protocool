class CommitteeMailer < ApplicationMailer
  helper :application

  def reminder(meeting, member)
    @meeting, @member = meeting, member
    @previous = meeting.previous_with_protocol
    @open_tasks = member.tasks.where(done: false).where.not(task_assignments: { emailed_at: nil }).includes(:meeting)
    subject = "תזכורת: פגישת #{setting.committee_name} #{I18n.l(meeting.scheduled_at, format: :short_day)} #{meeting.mail_tag}"
    @rsvp_links = Rsvp::STATUSES.except("maybe").to_h do |status, label|
      body = "#{label} לפגישה.\n\nנושאים שארצה להעלות (לא חובה):\n"
      [ status, "mailto:#{setting.gmail_address}?subject=#{ERB::Util.url_encode("#{label} – Re: #{subject}")}&body=#{ERB::Util.url_encode(body)}" ]
    end
    committee_mail(to: member.email, subject:)
  end

  def tasks(meeting, member)
    @meeting, @member = meeting, member
    @tasks = meeting.tasks.joins(:assignments).where(task_assignments: { member_id: member.id }).includes(:members)
    committee_mail(to: member.email,
                   subject: "המשימות שלך מפגישת #{setting.committee_name} #{I18n.l(meeting.scheduled_at, format: :short_day)}")
  end

  def community_letter(meeting)
    @meeting = meeting
    committee_mail(to: setting.community_email,
                   subject: "עדכון מ#{setting.committee_name} – הפגישה מ-#{I18n.l(meeting.scheduled_at, format: :short_day)}")
  end

  def test_message(to)
    committee_mail(to:, subject: "בדיקת חיבור – #{setting.committee_name}")
  end
end
