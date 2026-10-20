class RsvpsController < ApplicationController
  # Manual RSVP, for answers that came by WhatsApp or phone.
  def create
    meeting = Meeting.find(params[:meeting_id])
    member = Member.find(params[:member_id])
    if params[:status].blank?
      meeting.rsvps.where(member:).destroy_all
    else
      meeting.rsvps.find_or_initialize_by(member:).update!(status: params[:status], source: "manual", responded_at: Time.current)
    end
    redirect_to meeting_path(meeting, anchor: "attendance")
  end
end
