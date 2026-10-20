class Task < ApplicationRecord
  belongs_to :meeting
  has_many :assignments, class_name: "TaskAssignment", dependent: :destroy
  has_many :members, -> { order(:name) }, through: :assignments

  validates :description, presence: true

  def assignee_label = members.map(&:name).presence&.to_sentence || assignee_name.presence || "לא שויך"
  def co_assignees(member) = members.reject { |m| m == member }
end
