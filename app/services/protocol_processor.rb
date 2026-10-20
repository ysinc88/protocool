# Turns a raw protocol / transcript into a summary, decisions, concrete tasks per
# member, and a short letter to the community.
class ProtocolProcessor
  SCHEMA = {
    type: "object",
    properties: {
      summary: { type: "string", description: "פרוטוקול מסודר בעברית בפורמט Markdown: משתתפים, נושאים שנדונו (כותרת לכל נושא ותקציר הדיון)" },
      decisions: { type: "array", items: { type: "string" } },
      tasks: {
        type: "array",
        items: {
          type: "object",
          properties: {
            assignees: { type: "array", items: { type: "string" }, description: "שמות חברי הוועדה האחראים, בדיוק כפי שמופיעים ברשימה; ריק אם לא ברור" },
            description: { type: "string", description: "משימה קונקרטית וברת ביצוע, מתחילה בפועל" },
            due_on: { type: "string", description: "YYYY-MM-DD אם נקבע מועד, אחרת ריק" }
          },
          required: %w[assignees description due_on]
        }
      },
      community_letter: { type: "string", description: "מכתב קצר וחם לחברי הקהילה" }
    },
    required: %w[summary decisions tasks community_letter]
  }.freeze

  def initialize(meeting)
    @meeting = meeting
    @setting = Setting.current
  end

  def call
    data = ClaudeClient.json(prompt, schema: SCHEMA, system: system_prompt, model: "opus")
    members = Member.all.to_a
    Meeting.transaction do
      @meeting.tasks.where(emailed_at: nil).destroy_all
      data["tasks"].each do |t|
        names = Array(t["assignees"]).map(&:strip).compact_blank
        matched = names.index_with { |n| match_member(members, n) }
        @meeting.tasks.create!(members: matched.values.compact.uniq, description: t["description"],
                               assignee_name: matched.select { |_, m| m.nil? }.keys.join(", ").presence,
                               due_on: (Date.parse(t["due_on"]) rescue nil))
      end
      @meeting.update!(summary: data["summary"], decisions: data["decisions"].map { |d| "- #{d}" }.join("\n"),
                       community_letter: data["community_letter"], processed_at: Time.current,
                       processing_status: "done", processing_error: nil)
    end
  end

  private

  def match_member(members, name)
    return if name.blank?
    n = name.strip
    members.find { |m| m.name == n } || members.find { |m| m.name.include?(n) || n.include?(m.name) } ||
      members.find { |m| m.first_name == n.split.first }
  end

  def system_prompt
    <<~TXT
      את/ה מזכיר/ת של #{@setting.title.presence || "ועדת חינוך ביישוב"}. כותבים בעברית תקנית, ברורה ועניינית.
      לא ממציאים עובדות, שמות, תאריכים או החלטות שלא מופיעים בחומר. אם משהו לא ברור – משמיטים אותו.
    TXT
  end

  def prompt
    roster = Member.active.map { |m| "- #{m.name}#{" (#{m.role})" if m.role.present?}" }.join("\n")
    <<~TXT
      להלן החומר מפגישת הוועדה שהתקיימה ב#{@meeting.date_label}#{" ב#{@meeting.location}" if @meeting.location.present?}.
      החומר יכול להיות פרוטוקול שנכתב ידנית או תמלול אוטומטי של הקלטה עם תיוג דוברים (בתמלול יש שגיאות זיהוי – תקן/י לפי ההקשר).

      חברי הוועדה:
      #{roster.presence || "(לא הוגדרו)"}

      אישורי הגעה מראש (לא בהכרח מי שהגיע בפועל – העדיפו את מה שעולה מהחומר):
      #{@meeting.rsvps.includes(:member).map { |r| "- #{r.member.name}: #{r.label}" }.join("\n").presence || "(אין)"}

      סדר היום שתוכנן:
      #{@meeting.agenda.presence || "(לא הוגדר)"}

      נושאים שחברי הוועדה ביקשו להעלות:
      #{@meeting.topic_suggestions.where(accepted: true).map { |t| "- #{t.body} (#{t.author_name})" }.join("\n").presence || "(אין)"}

      ===== החומר =====
      #{@meeting.protocol_text}
      ===== סוף החומר =====

      הפק/י:
      1. summary – פרוטוקול מסודר ב-Markdown: "## משתתפים", ואז "## נושאים שנדונו" עם "### <נושא>" ותקציר קצר לכל נושא. בלי כותרת ראשית.
      2. decisions – רשימת ההחלטות שהתקבלו.
      3. tasks – משימות קונקרטיות: מי עושה מה ועד מתי. כל משימה משויכת לאחראי/ת מרשימת החברים (בדיוק בשם שמופיע ברשימה); כשכמה אנשים לוקחים משימה יחד – כולם ב-assignees. משימה בלי אחראי ברור – assignees ריק. הפגישה התקיימה ב-#{@meeting.scheduled_at.to_date.iso8601} (#{I18n.l(@meeting.scheduled_at, format: "%A")}); המר/י מועדים יחסיים ("עד יום חמישי", "עד השבוע הבא") לתאריך ביחס ליום הפגישה.
      4. community_letter – מכתב קצר (120–200 מילים) לחברי הקהילה: פתיחה חמה, מה נדון ומה הוחלט בשפה פשוטה, מה הלאה, וחתימה "#{@setting.chair_name.presence || "יו״ר הוועדה"}, #{@setting.committee_name}". בלי פרטים אישיים או רגישים, בלי שמות של ילדים, ובלי ויכוחים פנימיים.
    TXT
  end
end
