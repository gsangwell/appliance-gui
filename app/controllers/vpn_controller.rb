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
	
		network_info = StackAppliance.getNetworkInfo(ENV.fetch("PING_TEST") { "8.8.8.8" }, ENV.fetch("DNS_TEST") { "alces-software.com"} )

		config = `cat /opt/stack/vpnconfig.conf`
		config.gsub!("10.99.1.2", network_info['ip'].split("/")[0])

		send_data(config, :filename => "stack-vpn.conf")

	end
end
