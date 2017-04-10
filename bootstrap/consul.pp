include libkv::consul
package { "unzip":
} ->
file { "/etc/simp":
	ensure => directory,
} ->
file { "/etc/simp/bootstrap/":
	ensure => directory,
} ->
file { "/etc/simp/bootstrap/consul":
	ensure => directory,
} ->
exec { "/usr/bin/uuidgen >/etc/simp/bootstrap/consul/master_token":
	creates => '/etc/simp/bootstrap/consul/master_token',
} ->
exec { "/opt/puppetlabs/bin/puppet cert generate server.dc1.consul":
	creates => '/etc/puppetlabs/puppet/ssl/private_keys/server.dc1.consul.pem',
} ->
file { "/etc/simp/bootstrap/consul/server.dc1.consul.private.pem":
source => '/etc/puppetlabs/puppet/ssl/private_keys/server.dc1.consul.pem',
} ->
file { "/etc/simp/bootstrap/consul/server.dc1.consul.cert.pem":
source => '/etc/puppetlabs/puppet/ssl/certs/server.dc1.consul.pem',
} ->
file { "/etc/simp/bootstrap/consul/ca.pem":
source => '/etc/puppetlabs/puppet/ssl/ca/ca_crt.pem',
} -> 
Class["consul"] ->
exec { "/usr/local/bin/consul keygen >/etc/simp/bootstrap/consul/key":
  path => $::path,
  creates => '/etc/simp/bootstrap/consul/key',
}

