class ApplicationController < ActionController::Base
  include Clearance::Controller

  helper_method :bolt_on_enabled
  helper_method :redirect_unless_bolt_on

  def bolt_on_enabled(name)
    bolt_on = BoltOn.find_by(name: name)
    bolt_on.nil? ? false : bolt_on.enabled?
  end

  def redirect_unless_bolt_on(bolt_on)
    redirect_to root_path unless bolt_on_enabled(bolt_on)
  end
end
