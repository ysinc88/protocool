class TopicSuggestionsController < ApplicationController
  before_action { @meeting = Meeting.find(params[:meeting_id]) }

  def create
    @meeting.topic_suggestions.create!(params.expect(topic_suggestion: %i[body member_id]))
    redirect_to meeting_path(@meeting, anchor: "agenda")
  end

  def update
    @meeting.topic_suggestions.find(params[:id]).update!(params.expect(topic_suggestion: %i[accepted body]))
    redirect_to meeting_path(@meeting, anchor: "agenda")
  end

  def destroy
    @meeting.topic_suggestions.find(params[:id]).destroy
    redirect_to meeting_path(@meeting, anchor: "agenda")
  end
end
