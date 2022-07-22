#require 'appliance/appliance'

class SetupController < ApplicationController
	before_action :require_login
	before_action -> { redirect_unless_bolt_on("setup") } #, except: [:complete]
	before_action :setup_session

	def start
		redirect_to setup_user_path
	end

	def user
	end

	def user_settings
		user_params = params['setup_user']

		salt = rand(36**8).to_s(36)

		# Make sure user doesn't already exist
		if StackAppliance.user_exists?(user_params['username'])
			flash[:danger] = "Invalid username - please try again."
			redirect_to setup_user_path
		else
			session['setup']['user'] = {}
			session['setup']['user']['name'] = user_params['name']
			session['setup']['user']['username'] = user_params['username']
			session['setup']['user']['encrypted_pass'] = user_params['password'].crypt("$6$" + salt)

			redirect_to setup_network_path
		end
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

	def reconfigure
		# Check we have all the required settings
		check_settings

		settings = session['setup']
                settings['network']['interface'] = ENV.fetch("STACK_EXT_INT") { "eth3" }
		session['setup']['complete'] = true

		# Reconfigure as a background task
		StackAppliance.delay(run_at: 30.seconds.from_now).reconfigure(settings)

		flash[:info] = "Reconfiguring the appliance."
		redirect_to setup_complete_path
	end

	def complete
		settings = session['setup']

		@appliance_ip = settings['network']['ipv4']

		BoltOn.find_by(name: "setup").update(enabled: false)
	end

	def setup_session
		session['setup'] = {} if not defined? session['setup'] or session['setup'].nil?
	end

	def check_settings
		settings = session['setup']

		# User
		if not defined? settings['user'] or settings['user'].nil?
			redirect_to setup_user_path
		end

		# Network
		if not defined? settings['network'] or settings['network'].nil?
                        redirect_to setup_network_path
                end
	end
end
