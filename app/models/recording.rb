class Recording < ApplicationRecord
  belongs_to :meeting

  STATUSES = %w[recording uploaded transcribing done failed].freeze
  validates :status, inclusion: { in: STATUSES }

  def self.dir = Rails.root.join("storage", "recordings").tap(&:mkpath)

  def ext = mime_type.to_s.include?("mp4") ? "m4a" : (mime_type.to_s.include?("ogg") ? "ogg" : "webm")
  def audio_path = self.class.dir.join("#{id}.#{ext}")
  def append!(data)
    File.open(audio_path, "ab") { |f| f.write(data) }
    update_column(:bytes, File.size(audio_path))
  end

  def done? = status == "done"
  def busy? = status.in?(%w[uploaded transcribing])

  STAGE_LABELS = { "converting" => "ממיר את ההקלטה", "diarizing" => "מפריד בין דוברים", "transcribing" => "מתמלל" }.freeze

  def progress_label
    label = STAGE_LABELS.fetch(stage.to_s, "מתמלל")
    progress.to_i > 0 ? "#{label}… #{progress}%" : "#{label}…"
  end

  def speakers
    (segments || []).map { |s| s["speaker"] }.uniq.compact.sort_by { |s| s.to_s[/\d+/].to_i }
  end

  def speaker_label(code)
    (speaker_names || {})[code.to_s].presence || "דובר/ת #{code.to_s[/\d+/].to_i + 1}"
  end

  def transcript_text
    (segments || []).map { |s| "#{speaker_label(s['speaker'])}: #{s['text']}" }.join("\n")
  end
end
