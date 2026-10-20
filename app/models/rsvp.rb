class Rsvp < ApplicationRecord
  belongs_to :meeting
  belongs_to :member

  STATUSES = { "yes" => "מגיע/ה", "no" => "לא מגיע/ה", "maybe" => "אולי" }.freeze
  validates :status, inclusion: { in: STATUSES.keys }

  def label = STATUSES[status]
  def pill_class = { "yes" => "ok", "no" => "bad", "maybe" => "warn" }[status]
end
