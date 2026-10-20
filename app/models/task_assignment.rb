class TaskAssignment < ApplicationRecord
  belongs_to :task
  belongs_to :member

  scope :unsent, -> { where(emailed_at: nil) }
end
