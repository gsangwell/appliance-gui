#require 'appliance/appliance'

class SystemController < ApplicationController
	before_action :require_login

	def index
		@appliance_info = StackAppliance.getApplianceInfo
		@network_info = StackAppliance.getNetworkInfo(ENV.fetch("PING_TEST") { "8.8.8.8" }, ENV.fetch("DNS_TEST") { "alces-software.com"} )
		@support_info = StackAppliance.getSupportInfo(ENV.fetch("SUPPORT_VPN") { "support" }, ENV.fetch("SUPPORT_TEST") { "10.178.0.1" })
		@vpn_info = StackAppliance.getVpnInfo(ENV.fetch("STACK_VPN") { "stack-vpn" })
	end
end
