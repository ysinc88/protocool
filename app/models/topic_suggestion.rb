class TopicSuggestion < ApplicationRecord
  belongs_to :meeting
  belongs_to :member, optional: true

  validates :body, presence: true

  def author_name = member&.name || from_email || "—"
end
