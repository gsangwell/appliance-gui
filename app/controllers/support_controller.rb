class SupportController < ApplicationController
	before_action :require_login

	def enable
		if StackAppliance.enableSupport(ENV.fetch("SUPPORT_VPN") { "support" }) 
			flash[:success] = 'Alces Support Mode has been enabled.'
		else
			flash[:error] = 'Encountered an error whilst trying to enable Alces Support Mode.'
		end

		redirect_back(fallback_location: root_path)
	end

	def disable
		if StackAppliance.disableSupport(ENV.fetch("SUPPORT_VPN") { "support" })
                        flash[:success] = 'Alces Support Mode has been disabled.'
                else
                        flash[:error] = 'Encountered an error whilst trying to disable Alces Support Mode.'
                end

                redirect_back(fallback_location: root_path)
	end	
end
