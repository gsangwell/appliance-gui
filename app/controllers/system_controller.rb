require 'appliance/appliance'

class SystemController < ApplicationController
	before_action :require_login

	def index
		@appliance_info = Appliance.getApplianceInfo
		@network_info = Appliance.getNetworkInfo
		@support_info = Appliance.getSupportInfo
	end
end
