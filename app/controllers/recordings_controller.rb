class RecordingsController < ApplicationController
  skip_forgery_protection only: :chunk
  before_action { @meeting = Meeting.find(params[:meeting_id]) }
  before_action :set_recording, except: :create

  def create
    rec = @meeting.recordings.create!(mime_type: params[:mime_type].to_s.split(";").first.presence || "audio/webm")
    render json: { id: rec.id, chunk_url: chunk_meeting_recording_path(@meeting, rec), finish_url: finish_meeting_recording_path(@meeting, rec) }
  end

  # Raw audio bytes, appended in order. The client sends chunks sequentially with a sequence number.
  def chunk
    @recording.append!(request.body.read)
    head :ok
  end

  def finish
    @recording.update!(status: "uploaded", num_speakers: params[:num_speakers].presence&.to_i, finished_at: Time.current)
    TranscribeJob.perform_later(@recording)
    respond_to do |f|
      f.json { render json: { url: meeting_path(@meeting, anchor: "recording") } }
      f.html { redirect_to meeting_path(@meeting, anchor: "recording") }
    end
  end

  def retry
    @recording.update!(status: "uploaded", error: nil, num_speakers: params[:num_speakers].presence&.to_i || @recording.num_speakers)
    TranscribeJob.perform_later(@recording)
    redirect_to meeting_path(@meeting, anchor: "recording"), notice: "התמלול הופעל מחדש"
  end

  def show
    @members = Member.active
  end

  def update
    names = params.fetch(:speaker_names, {}).permit!.to_h.transform_values(&:strip)
    @recording.update!(speaker_names: names)
    redirect_to meeting_recording_path(@meeting, @recording), notice: "שמות הדוברים נשמרו"
  end

  def use_as_protocol
    @meeting.update!(protocol_text: @meeting.transcript_text, protocol_source: "recording", processing_status: "queued", processing_error: nil)
    ProcessProtocolJob.perform_later(@meeting)
    redirect_to meeting_path(@meeting, anchor: "protocol"), notice: "התמלול נשלח לעיבוד לפרוטוקול, משימות ומכתב…"
  end

  def audio
    send_file @recording.audio_path, type: @recording.mime_type, disposition: "inline"
  end

  def destroy
    File.delete(@recording.audio_path) if File.exist?(@recording.audio_path)
    @recording.destroy
    redirect_to meeting_path(@meeting, anchor: "recording"), notice: "ההקלטה נמחקה"
  end

  private

  def set_recording = @recording = @meeting.recordings.find(params[:id])
end
