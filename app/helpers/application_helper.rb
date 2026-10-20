module ApplicationHelper
  MD = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new(filter_html: true, hard_wrap: true), autolink: true, lax_spacing: true)

  def markdown(text)
    MD.render(text.to_s).html_safe
  end

  def duration_label(seconds)
    return "" unless seconds
    s = seconds.to_i
    format(s >= 3600 ? "%d:%02d:%02d" : "%2$d:%3$02d", s / 3600, (s % 3600) / 60, s % 60)
  end

  def relative_day(time)
    days = (time.to_date - Date.current).to_i
    case days
    when 0 then "היום"
    when 1 then "מחר"
    when 2 then "מחרתיים"
    when 3.. then "בעוד #{days} ימים"
    when -1 then "אתמול"
    else "לפני #{-days} ימים"
    end
  end
end
