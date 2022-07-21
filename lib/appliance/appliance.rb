require 'net/ip'
require 'net/ping'
require 'resolv'
require 'time'
require 'remote_ruby'

class Appliance
	def self.getApplianceInfo
		info = {}

                remotely(server: 'stack-controller') do
                        config = File.readlines('/etc/kolla/globals.yml')
                        fqdn = config.find {|line| line.match(/^kolla_external_fqdn:/) }.match(/^kolla_external_fqdn: "?(.*?)"?$/)[1]

                        info['horizon'] = "https://#{fqdn}"
                end

                return info
	end

	def self.getNetworkInfo
		info = {}

		remotely(server: 'directory') do
                        require 'resolv'

                        info['dns'] = Resolv::DNS::Config.default_config_hash[:nameserver].join(",")
                end

		remotely(server: 'stack-controller') do
			require 'net/ip'
			require 'net/ping'
			require 'resolv'

			info['ip'] = `ip -4 addr show eth3 | grep 'inet' | awk '{print $2}' | head -1`
			info['gateway'] = Net::IP.routes.gateways.find {|gateway| gateway.prefix == "default"}.via
			#info['dns'] = Resolv::DNS::Config.default_config_hash[:nameserver].join(",")
			info['ping_test'] = Net::Ping::External.new("8.8.8.8").ping?
			info['dns_test'] = Resolv::DNS.new().getaddress("alces-software.com")
		end

		return info		
	end

	def self.getSupportInfo(vpnclient)

		status = `systemctl status openvpn-client@#{vpnclient} | grep "Active:"`

		support = {}
		support['enabled'] = status.match(/Active: active \(running\)/)

		if support['enabled']
			support['enabled_since'] = status.match(/Active: .*;(.*)/)[1]
			support['ping_hub'] = true
		end

		return support
	end

	def self.enableSupport(vpnclient)
		out, status = Open3.capture2("systemctl start openvpn-client@#{vpnclient}")
		return status.success?
	end

	def self.disableSupport(vpnclient)
		out, status = Open3.capture2("systemctl stop openvpn-client@#{vpnclient}")
                return status.success?
	end

	def self.shutdown(user)
		out, status = Open3.capture2("shutdown -h 1 'Appliance shutdown initiated by user \'#{user}\'.'")
                return status.success?
	end

	def self.restart(user)
		out, status = Open3.capture2("shutdown -r 1 'Appliance restart initiated by user \' #{user}\'.'")
                return status.success?
        end

	def self.reconfigure(settings)

		settings['network'].each do |key, value|
			`echo "#{key} => #{value}" >> /tmp/settings.txt`
		end

		return true

	end

	def self.getDefaultRoute
		return Net::IP.routes.gateways.find {|gateway| gateway.prefix == "default"}.via
	end
end
