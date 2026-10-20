class PollInboxJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: "inbox", duration: 10.minutes if respond_to?(:limits_concurrency)

  def perform
    InboxPoller.new.call
  end
end
