class SendTasksJob < ApplicationJob
  queue_as :mail

  def perform(meeting)
    TaskAssignment.unsent.joins(:task).where(tasks: { meeting_id: meeting.id }).includes(:member)
                  .group_by(&:member).each do |member, assignments|
      CommitteeMailer.tasks(meeting, member).deliver_now
      TaskAssignment.where(id: assignments.map(&:id)).update_all(emailed_at: Time.current)
      Task.where(id: assignments.map(&:task_id), emailed_at: nil).update_all(emailed_at: Time.current)
    end
    meeting.update!(tasks_sent_at: Time.current)
  end
end
