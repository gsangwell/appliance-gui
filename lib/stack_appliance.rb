require 'net/ip'
require 'net/ping'
require 'resolv'
require 'time'
require 'remote_ruby'
require 'open3'

class StackAppliance
	def self.getApplianceInfo
		info = {}

		begin
	                remotely(server: 'stack-controller') do
        	                config = File.readlines('/etc/kolla/globals.yml')
                	        fqdn = config.find {|line| line.match(/^kolla_external_fqdn:/) }.match(/^kolla_external_fqdn: "?(.*?)"?$/)[1]

	                        info['horizon'] = "https://#{fqdn}"
        	        end
		rescue => e
			info['horizon'] = "Error"
		end

                return info
	end

	def self.getNetworkInfo(ping_test, dns_test)
		info = {}

		begin
			remotely(server: 'directory') do
                        	require 'resolv'

	                        dns = Resolv::DNS::Config.default_config_hash[:nameserver].join(",")

				info['dns'] = dns.empty? ? "No DNS Server" : dns
                	end
		rescue => e
			info['dns'] = "Error"
		end

		begin
			remotely(server: 'stack-controller') do
				require 'net/ip'
				require 'net/ping'
				require 'resolv'

				ipv4 = `ip -4 addr show eth3 | grep 'inet' | awk '{print $2}' | head -1`.to_s
				default_route = Net::IP.routes.gateways.find {|gateway| gateway.prefix == "default"}

				info['ip'] = ipv4.empty? ? "No IP Address." : ipv4
				info['gateway'] = default_route.nil? ? "No default route." : default_route.via
			end
		rescue => e
			info['ip'] = "Error"
			info['gateway'] = "Error"
		end

		begin
			resolv = Resolv::DNS.new()
			resolv.timeouts = 2
			info['dns_test'] = resolv.getaddress("#{dns_test}")
		rescue => e
			info['dns_test'] = false
		end

		info['ping_test'] = Net::Ping::External.new("#{ping_test}").ping?

		return info		
	end

	def self.getSupportInfo(vpnclient, support_test)

		status = `systemctl status openvpn-client@#{vpnclient} | grep "Active:"`

		support = {}
		support['enabled'] = status.match(/Active: active \(running\)/)

		if support['enabled']
			support['enabled_since'] = status.match(/Active: .*;(.*)/)[1]
			support['ping_hub'] = Net::Ping::External.new("#{support_test}").ping?
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

	def self.user_exists?(username)
		
		exists = false

		begin
			remotely(server: 'directory') do
				require 'open3'

				out, status = Open3.capture2("id #{username}")

				exists = true if status.exitstatus == 0
			end
		rescue => e
			return true
		end

		return exists
	end


	def self.reconfigure(settings)

		# Reconfigure network settings
		reconfigureNetwork(settings['network'])

		# Add admin user
		addUser(settings['user'])
	end

	private_class_method def self.reconfigureNetwork(settings)
	
		status = nil

		begin

			remotely(server: 'stack-controller') do
				require 'open3'

				# Modify the network script
				ext_net = File.read("/etc/sysconfig/network-scripts/ifcfg-#{settings['interface']}")
				ext_net.gsub!(/^IPADDR=.*$/, "IPADDR=#{settings['ipv4']}")
				ext_net.gsub!(/^NETMASK=.*$/, "NETMASK=#{settings['netmask']}")
				ext_net.gsub!(/^GATEWAY=.*$/, "GATEWAY=#{settings['gateway']}")
				File.open("/etc/sysconfig/network-scripts/ifcfg-#{settings['interface']}", "w") {|file| file.puts ext_net }

				out, status = Open3.capture2("ifdown #{settings['interface']} && ifup #{settings['interface']}")
			end

		rescue => e
			return false
		end

		return status.success?
	end

	private_class_method def self.addUser(user)
	
		status = nil

		begin
			remotely(server: 'directory') do

				require 'open3'

				out, status = Open3.capture2("useradd #{user['username']} && echo '#{user['username']}:#{user['encrypted_pass']}' | chpasswd -e ; make -C /var/yp")
			end
		rescue => e
			return false
		end

		return status.success?
	end
end
