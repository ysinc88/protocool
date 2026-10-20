class TasksController < ApplicationController
  before_action { @meeting = Meeting.find(params[:meeting_id]) }

  def create
    @meeting.tasks.create!(task_params)
    redirect_to meeting_path(@meeting, anchor: "tasks")
  end

  def update
    task = @meeting.tasks.find(params[:id])
    task.update!(task_params)
    redirect_back_or_to meeting_path(@meeting, anchor: "tasks")
  end

  def destroy
    @meeting.tasks.find(params[:id]).destroy
    redirect_to meeting_path(@meeting, anchor: "tasks")
  end

  private

  def task_params = params.expect(task: [ :description, :due_on, :done, member_ids: [] ])
end
