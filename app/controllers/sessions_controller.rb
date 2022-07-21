class SessionsController < ApplicationController
  include Clearance::Controller

  def create
    if User.authenticate(params[:session][:username], params[:session][:password])
      user = User.find_or_create_by!(username: params[:session][:username])
      sign_in(user)

      if bolt_on_enabled("setup")
	redirect_to setup_path
      else
        redirect_to root_path
      end
    else
      flash[:danger] = 'Invalid username or password'
      redirect_back(fallback_location: login_path)
    end
  end

  def destroy
    sign_out
    redirect_to login_path
  end
end
