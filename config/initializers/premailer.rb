# Inline the mailer CSS: Gmail drops <body> styles, which loses RTL direction.
Premailer::Rails.config.merge!(preserve_styles: true, remove_ids: false, generate_text_part: false)
