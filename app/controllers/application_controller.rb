class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  helper_method :setting

  private

  def setting = @setting ||= Setting.current
end
