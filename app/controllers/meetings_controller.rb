require "open3"

class MeetingsController < ApplicationController
  before_action :set_meeting, except: %i[index new create]

  def index
    @upcoming = Meeting.upcoming.includes(:topic_suggestions, :rsvps)
    @past = Meeting.past.includes(:tasks).limit(30)
    @open_tasks = Task.where(done: false).where.not(emailed_at: nil).includes(:members, :meeting).order(:due_on)
  end

  def show
    @meeting = Meeting.includes(rsvps: :member).find(params[:id])
    @recordings = @meeting.recordings
    @members = Member.active
  end

  def new
    last = Meeting.order(:scheduled_at).last
    default_time = last ? last.scheduled_at + 1.month : 1.week.from_now.change(hour: 20)
    @meeting = Meeting.new(scheduled_at: default_time, location: last&.location || setting.default_location)
  end

  def create
    @meeting = Meeting.new(meeting_params)
    if @meeting.save
      redirect_to @meeting, notice: "הפגישה נקבעה. תזכורת תישלח #{I18n.l(@meeting.reminder_due_at, format: :meeting)}"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @meeting.update(meeting_params)
      redirect_to @meeting, notice: "נשמר"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @meeting.destroy
    redirect_to root_path, notice: "הפגישה נמחקה"
  end

  def reminder_preview
    member = Member.active.first || Member.new(name: "חבר/ת ועדה", email: "example@example.com")
    @mail = CommitteeMailer.reminder(@meeting, member)
    render html: @mail.html_part.body.decoded.html_safe, layout: false
  rescue => e
    redirect_to @meeting, alert: e.message
  end

  def send_reminder
    return redirect_to(@meeting, alert: "צריך להגדיר Gmail בהגדרות") unless setting.mail_configured?
    SendRemindersJob.perform_later(@meeting.id)
    redirect_to @meeting, notice: "התזכורת נשלחת ל-#{Member.active.count} חברי הוועדה"
  end

  def protocol
    text = params.dig(:meeting, :protocol_text).to_s
    source = "manual"
    if (file = params.dig(:meeting, :protocol_file)).present?
      text = extract_text(file)
      source = file.original_filename
    end
    @meeting.update!(protocol_text: text, protocol_source: source)
    if params[:process].present? && text.present?
      @meeting.update!(processing_status: "queued")
      ProcessProtocolJob.perform_later(@meeting)
    end
    redirect_to meeting_path(@meeting, anchor: "protocol"), notice: params[:process] ? "הפרוטוקול נשלח לעיבוד…" : "הפרוטוקול נשמר"
  rescue => e
    redirect_to meeting_path(@meeting, anchor: "protocol"), alert: "לא הצלחתי לקרוא את הקובץ: #{e.message}"
  end

  def process_protocol
    return redirect_to(@meeting, alert: "אין עדיין פרוטוקול לעבד") if @meeting.protocol_text.blank?
    @meeting.update!(processing_status: "queued", processing_error: nil)
    ProcessProtocolJob.perform_later(@meeting)
    redirect_to meeting_path(@meeting, anchor: "protocol"), notice: "הפרוטוקול נשלח לעיבוד…"
  end

  def send_tasks
    return redirect_to(@meeting, alert: "צריך להגדיר Gmail בהגדרות") unless setting.mail_configured?
    n = TaskAssignment.unsent.joins(:task).where(tasks: { meeting_id: @meeting.id }).distinct.count(:member_id)
    SendTasksJob.perform_later(@meeting)
    redirect_to meeting_path(@meeting, anchor: "tasks"), notice: "המשימות נשלחות ל-#{n} חברי ועדה"
  end

  def send_letter
    return redirect_to(@meeting, alert: "צריך להגדיר Gmail וכתובת לקהילה בהגדרות") unless setting.mail_configured? && setting.community_email.present?
    CommitteeMailer.community_letter(@meeting).deliver_later(queue: :mail)
    @meeting.update!(letter_sent_at: Time.current)
    redirect_to meeting_path(@meeting, anchor: "letter"), notice: "המכתב נשלח ל-#{setting.community_email}"
  end

  def add_topics_to_agenda
    topics = @meeting.topic_suggestions.where(accepted: true).map { |t| "- #{t.body}" }
    lines = @meeting.agenda.to_s.lines.map(&:strip)
    new_lines = topics.reject { |t| lines.include?(t) }
    @meeting.update!(agenda: [ @meeting.agenda.to_s.strip, *new_lines ].compact_blank.join("\n"))
    redirect_to meeting_path(@meeting, anchor: "agenda"), notice: "#{new_lines.size} נושאים נוספו לסדר היום"
  end

  private

  def set_meeting = @meeting = Meeting.find(params[:id])

  def meeting_params
    params.expect(meeting: %i[scheduled_at location agenda summary decisions community_letter])
  end

  def extract_text(file)
    path = file.tempfile.path
    case File.extname(file.original_filename).downcase
    when ".pdf"
      run_text("pdftotext", "-layout", path, "-")
    when ".docx"
      xml = run_text("unzip", "-p", path, "word/document.xml")
      CGI.unescapeHTML(xml.gsub(%r{</w:p>}, "\n").gsub(/<w:tab\/>/, "\t").gsub(/<[^>]+>/, "")).strip
    else
      File.read(path).force_encoding("UTF-8").scrub
    end
  end

  def run_text(*cmd)
    out, err, st = Open3.capture3(*cmd)
    raise err.presence || "#{cmd.first} failed" unless st.success?
    out.force_encoding("UTF-8").scrub
  end
end
