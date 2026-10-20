class ProcessProtocolJob < ApplicationJob
  queue_as :heavy

  def perform(meeting)
    meeting.update!(processing_status: "running", processing_error: nil)
    ProtocolProcessor.new(meeting).call
  rescue => e
    meeting.update!(processing_status: "failed", processing_error: e.message)
    raise
  end
end
