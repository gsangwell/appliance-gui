require 'net/ip'
require 'net/ping'
require 'resolv'
require 'time'
require 'remote_ruby'
require 'open3'
require 'linux_stat'

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
                

		info['uptime'] = ActiveSupport::Duration.build(LinuxStat::OS.uptime_i).inspect

		if File.file?("/run/systemd/shutdown/scheduled")
			info['scheduled_power'] = {}
			info['scheduled_power']['type'] = `cat /run/systemd/shutdown/scheduled | grep MODE | awk -F= '{print $2}'`.strip
			info['scheduled_power']['timestamp'] = Time.at(`cat /run/systemd/shutdown/scheduled | head -n 1 | cut -c6-15`.to_i).strftime("%Y-%m-%d %H:%M:%S")
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

				ipv4 = `ip -4 addr show eth3 | grep 'inet' | awk '{print $2}' | head -1`.to_s
				default_route = `ip route | grep default | awk '{print $3}'`.to_s

				info['ip'] = ipv4.empty? ? "No IP Address." : ipv4
				info['gateway'] = default_route.nil? ? "No default route." : default_route
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

		info['ping_test'] = Net::Ping::External::new.ping?("#{ping_test}", 1, 1, 2)

		return info		
	end

	def self.getSupportInfo(vpnclient, support_test)

		status = `systemctl status openvpn-client@#{vpnclient} | grep "Active:"`

		support = {}
		support['enabled'] = status.match?(/Active: active \(running\)/)

		if support['enabled']
			support['enabled_since'] = status.match(/Active: .*;(.*)/)[1]
			support['ping_hub'] = Net::Ping::External.new.ping?("#{support_test}", 1, 1, 2)
		end

		return support
	end

	def self.getVpnInfo(vpnserver)

		info = {}

		#begin
                        remotely(server: 'stack-controller') do

				status = `systemctl status openvpn-server@#{vpnserver} | grep "Active:"`

				info['status'] = status.match?(/Active: active \(running\)/)

                        end
                #rescue => e
                #        info['status'] = false
		#	puts e
                #end

		return info

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

	def self.startVpn(vpnserver)
                status = nil

                begin
                        remotely(server: 'stack-controller') do
                                require 'open3'

                                out, status = Open3.capture2("systemctl start openvpn-server@#{vpnserver}")
                        end
                rescue => e
                        return false
                end

                return status.success?
        end

	def self.stopVpn(vpnserver)
		status = nil

		begin
			remotely(server: 'stack-controller') do
				require 'open3'

				out, status = Open3.capture2("systemctl stop openvpn-server@#{vpnserver}")
			end
		rescue => e
			return false
		end

		return status.success?
	end

        def self.getVpnConfig(vpnserver)
                output = ""

                begin
                        remotely(server: 'stack-controller') do

                                ipv4 = `ip -4 addr show eth3 | grep 'inet' | awk '{print $2}' | head -1 | cut -d/ -f1`.to_s.strip
                                template = `cat /etc/openvpn/client/#{vpnserver}.template`

                                output = template.gsub("REMOTE_IP", ipv4)
                        end
                rescue => e
                        return ""
                end

                return output
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
		reconfigureDNS(settings['network'])

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

	private_class_method def self.reconfigureDNS(settings)

		status = nil

                begin

                        remotely(server: 'directory') do
				require 'open3'

				pri_net = File.read("/etc/sysconfig/network-scripts/ifcfg-eth0")
                                pri_net.gsub!(/^DNS1=.*$/, "DNS1=#{settings['dns']}")
				File.open("/etc/sysconfig/network-scripts/ifcfg-eth0", "w") {|file| file.puts pri_net }

				out, status = Open3.capture2("ifdown eth0 && ifup eth0")
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

				out, status = Open3.capture2("useradd -g admins -d /users/#{user['username']} -m #{user['username']} && echo '#{user['username']}:#{user['encrypted_pass']}' | chpasswd -e ; make -C /var/yp ;")
				
				if status.success?
					`su - #{user['username']} -c "ssh-keygen -t rsa -f ~/.ssh/id_rsa -N '' ; cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys ; chmod 600 ~/.ssh/authorized_keys"`
				end
			end

			if status.success?

				status = nil

				remotely(server: 'stack-controller') do

					require 'open3'

					out, status = Open3.capture2("source /opt/stack/kolla/bin/activate && source /etc/kolla/admin-openrc.sh && openstack user create #{user['username']} && openstack role add --user #{user['username']} --project admin admin && openstack role add --user gary --system all admin")


				end

			end
		rescue => e
			return false
		end

		return status.success?
	end
end
