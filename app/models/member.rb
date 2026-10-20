class Member < ApplicationRecord
  has_many :task_assignments, dependent: :destroy
  has_many :tasks, through: :task_assignments
  has_many :topic_suggestions, dependent: :nullify
  has_many :rsvps, dependent: :destroy

  normalizes :email, with: ->(e) { e.strip.downcase }
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :active, -> { where(active: true).order(:name) }

  def first_name = name.split.first
end
