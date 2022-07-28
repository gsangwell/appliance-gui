class VpnController < ApplicationController
        before_action :require_login

	def start
		if StackAppliance.startVpn("stack-vpn")
			flash[:success] = 'Started VPN service.'
                else
			flash[:error] = 'Encountered an error whilst trying to start the VPN service.'
                end

                redirect_back(fallback_location: root_path)
	end

	def stop
                if StackAppliance.stopVpn("stack-vpn")
                        flash[:success] = 'Stopped VPN service.'
                else
                        flash[:error] = 'Encountered an error whilst trying to stop the VPN service.'
                end

                redirect_back(fallback_location: root_path)
        end

	def download_config
	
                config_file = StackAppliance.getVpnConfig("stack-vpn")
		send_data(config_file, :filename => "stack-vpn.conf")

	end
end
