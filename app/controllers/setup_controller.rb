require 'appliance/appliance'

class SetupController < ApplicationController
	before_action :require_login
	before_action -> { redirect_unless_bolt_on("setup") }, except: [:complete]
	before_action :setup_session

	def start
		redirect_to setup_network_path
	end

	def network
	end

	def network_settings
		network_params = params['setup_network']

		session['setup']['network'] = network_params

		redirect_to setup_confirm_path
	end

	def confirm
		# Check we have all the required settings
		check_settings
	end

	def reconfigure_appliance
		settings = session['setup']
		
		# Check we have all the required settings
		check_settings

		# Disable the setup bolt on
		BoltOn.find_by(name: "setup").update(enabled: false)

		if Appliance.reconfigure(settings)
			flash[:success] = 'Reconfiguring the appliance.'
		else
			flash[:danger] = 'An error occuring trying to reconfigure the appliance.'
		end
		
		redirect_to setup_complete_path
	end

	def setup_session
		session['setup'] = {} if not defined? session['setup'] or session['setup'].nil?
	end

	def check_settings
		settings = session['setup']

		# Check the required sections have been completed
		if not defined? settings['network'] or settings['network'].nil?
                        redirect_to setup_network_path
                end
	end
end
