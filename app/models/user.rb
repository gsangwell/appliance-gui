class User < ApplicationRecord
  include Clearance::User
  require 'rpam2'

  def email_optional?
    true
  end

  def password_optional?
    true
  end

  def self.authenticate(username, password)
    Rpam2.auth("system-auth", username, password)
  end
end
