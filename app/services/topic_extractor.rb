# Reads a member's reply to the reminder: are they coming, and which agenda topics do they propose.
class TopicExtractor
  SCHEMA = {
    type: "object",
    properties: {
      attending: { type: "string", enum: %w[yes no maybe unknown] },
      note: { type: "string", description: "הערה קצרה על ההגעה אם יש (למשל: 'אאחר בחצי שעה'), אחרת ריק" },
      topics: { type: "array", items: { type: "string" } }
    },
    required: %w[attending note topics]
  }.freeze

  def self.call(text)
    prompt = <<~TXT
      זו תשובה של חבר/ת ועדת חינוך למייל תזכורת לפגישה, שביקש לאשר הגעה ולהציע נושאים לדיון.
      - attending: האם הכותב/ת מגיע/ה – yes / no / maybe (אולי, לא בטוח, אנסה), או unknown אם לא נאמר.
      - note: הערה קצרה על ההגעה אם יש.
      - topics: הנושאים שהוצעו לדיון, כל נושא כמשפט קצר וברור. אישור הגעה, תודה או "אין לי נושאים" אינם נושאים.

      #{text.truncate(6000)}
    TXT
    ClaudeClient.json(prompt, schema: SCHEMA, model: "haiku", timeout: 180)
  end
end
