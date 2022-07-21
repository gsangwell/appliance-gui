class SupportController < ApplicationController
	before_action :require_login

	def enable
		if Appliance.enableSupport(ENV.fetch("SUPPORT_VPN") { "support" }) 
			flash[:success] = 'Alces Support Mode has been enabled.'
		else
			flash[:error] = 'Encountered an error whilst trying to enable Alces Support Mode.'
		end

		redirect_to home_path
	end

	def disable
		if Appliance.disableSupport(ENV.fetch("SUPPORT_VPN") { "support" })
                        flash[:success] = 'Alces Support Mode has been disabled.'
                else
                        flash[:error] = 'Encountered an error whilst trying to disable Alces Support Mode.'
                end

                redirect_to home_path
	end	
end
