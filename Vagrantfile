# vim: set ft=ruby:
Vagrant.configure(2) do |config|
	ENV['VAGRANT_DEFAULT_PROVIDER'] = 'docker'
	ENV['VAGRANT_NO_PARALLEL'] = 'yes'
	config.vm.define "consul" do |config|
		config.vm.synced_folder ".", "/vagrant", disabled: true
		config.vm.provider "docker" do |d|
			d.image = "consul"
			d.has_ssh = false
			d.ports = [
				"8500:8500",
			]
		end
	end
	config.vm.define "etcd" do |config|
		config.vm.synced_folder ".", "/vagrant", disabled: true
		config.vm.provider "docker" do |d|
			d.image = "elcolio/etcd"
			d.has_ssh = false
			d.ports = [
				"2379:2379",
			]
		end
	end
	# vagrant_root = File.dirname(__FILE__);
	# config.vm.define "puppet" do |config|
	# 	config.vm.synced_folder ".", "/vagrant", disabled: true
	# 	config.vm.provider "docker" do |d|
	# 		d.image = "simpproject/centos:7-ruby21"
	# 		d.has_ssh = true
	# 		d.volumes = [
	# 			"#{vagrant_root}:/vagrant:z",
	# 		]
	# 		d.cmd = [ "bash", "-c", "sudo yum install -y openssh-server && sudo /usr/sbin/sshd"]
	# 	end

	# end
end
