class TranscribeJob < ApplicationJob
  queue_as :heavy

  def perform(recording)
    recording.update!(status: "transcribing", error: nil, stage: nil, progress: nil)
    Transcriber.new(recording).call
  rescue => e
    recording.update!(status: "failed", error: e.message)
    raise
  end
end
