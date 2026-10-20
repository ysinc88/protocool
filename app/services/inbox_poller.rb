require "net/imap"

# Reads replies to reminder e-mails from the committee Gmail inbox and stores the
# topics members proposed for the next meeting.
class InboxPoller
  QUOTE_MARKERS = [
    /^On .+wrote:\s*$/i, /^בתאריך .+:\s*$/, /^בתאריך .+(כתב|כתבה|כתב\/ה)[^\n]*:\s*$/, /^-{2,}\s*Original Message/i,
    /^-{5,}/, /^From: /, /^מאת: /, /^‫?בתאריך יום/
  ].freeze

  def initialize(setting = Setting.current)
    @setting = setting
  end

  def call
    return 0 unless @setting.mail_configured?
    count = 0
    imap = Net::IMAP.new("imap.gmail.com", port: 993, ssl: true)
    imap.login(@setting.gmail_address, @setting.gmail_app_password.to_s.delete(" "))
    imap.select("INBOX")
    ids = imap.search([ "SUBJECT", "VC-", "SINCE", 30.days.ago.strftime("%d-%b-%Y") ])
    ids.each_slice(50) do |slice|
      imap.fetch(slice, "RFC822")&.each do |msg|
        count += handle(Mail.read_from_string(msg.attr["RFC822"]))
      end
    end
    count
  ensure
    imap&.logout rescue nil
    imap&.disconnect rescue nil
  end

  private

  def handle(mail)
    message_id = mail.message_id.presence || Digest::SHA1.hexdigest(mail.to_s)
    return 0 if ProcessedMessage.exists?(message_id:)
    from = Array(mail.from).first.to_s.downcase
    meeting = Meeting.find_by_subject(mail.subject)
    added = 0
    if meeting && from != @setting.gmail_address.to_s.downcase
      body = reply_text(mail)
      if body.present?
        member = Member.find_by(email: from)
        reply = begin
          TopicExtractor.call("נושא המייל: #{mail.subject}\n\n#{body}")
        rescue ClaudeClient::Error => e
          Rails.logger.warn("reply extraction failed: #{e.message}")
          { "attending" => guess_attending(mail.subject, body), "note" => "", "topics" => [ body.truncate(1000) ] }
        end
        if member && reply["attending"].in?(Rsvp::STATUSES.keys)
          rsvp = meeting.rsvps.find_or_initialize_by(member:)
          rsvp.update!(status: reply["attending"], note: reply["note"].presence, source: "email", responded_at: mail.date || Time.current)
          added += 1
        end
        reply["topics"].map(&:strip).compact_blank.each do |t|
          meeting.topic_suggestions.create!(member:, from_email: from, body: t, message_id:)
          added += 1
        end
      end
    end
    ProcessedMessage.create!(message_id:)
    added
  end

  # Fallback when Claude is unavailable: the RSVP buttons put the answer in the subject.
  def guess_attending(subject, body)
    text = "#{subject} #{body.lines.first}"
    return "no" if text.include?("לא מגיע")
    return "maybe" if text.include?("אולי")
    "yes" if text.include?("מגיע")
  end

  def reply_text(mail)
    part = mail.multipart? ? (mail.text_part || mail.html_part) : mail
    text = part.decoded.to_s.force_encoding(part.charset || "UTF-8").encode("UTF-8", invalid: :replace, undef: :replace)
    text = ActionView::Base.full_sanitizer.sanitize(text) if part.mime_type == "text/html"
    lines = []
    text.each_line do |l|
      break if QUOTE_MARKERS.any? { |re| l.strip.match?(re) }
      next if l.start_with?(">")
      lines << l
    end
    lines.join.strip
  end
end
