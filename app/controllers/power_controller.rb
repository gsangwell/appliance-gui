class PowerController < ApplicationController
	before_action :require_login

        def shutdown
		if Appliance.shutdown(current_user.username)
			flash[:success] = 'Requested appliance shutdown.'
                else
                        flash[:error] = 'Encountered an error whilst trying to shutdown the appliance.'
                end

                redirect_back(fallback_location: root_path)
        end

        def restart
		if Appliance.restart(current_user.username)
                        flash[:success] = 'Requested appliance restart.'
                else
                        flash[:error] = 'Encountered an error whilst trying to restart the appliance.'
                end

                redirect_back(fallback_location: root_path)
        end
end
