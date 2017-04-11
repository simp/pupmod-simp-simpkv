# == Class libkv::consul
# vim: set expandtab ts=2 sw=2:
#
# This class uses solarkennedy/consul to initialize .
#
class libkv::consul(
  $server = false,
  $version = '0.8.0',
  $use_puppet_pki = true,
  $bootstrap = false,
  $dont_copy_files = false,
  $serverhost = undef,
  $advertise = undef,
  $datacenter = undef,
  $ca_file_name = undef,
  $private_file_name = undef,
  $cert_file_name = undef,
  $config_hash = undef,
) {
  package { "unzip": }
  if ($bootstrap == true) {
    $_bootstrap_hash = { "bootstrap_expect" => 1 }
  } else {
    $_bootstrap_hash = {}
  }
  if ($datacenter == undef) {
    $_datacenter = {}
  } else {
    $_datacenter = { "datacenter" => $datacenter }
  }
  if ($serverhost == undef) {
    if ($::servername == undef) {
      $_serverhost = $::fqdn
    } else {
      $_serverhost = $::servername
    }
  } else {
    $_serverhost = $serverhost
  }
  if ($advertise == undef) {
    $_advertise = $::ipaddress
  } else {
    $_advertise = $advertise
  }
  $keypath = '/etc/simp/bootstrap/consul/key'
  $keydata = file($keypath, "/dev/null")
  if ($keydata != undef) {
    $_key_hash = { 'encrypt' => $keydata.chomp }
  } else {
    $_key_hash = {}
  }
  $master_token_path = '/etc/simp/bootstrap/consul/master_token'
  $token = file($master_token_path, "/dev/null")
  if ($token != undef) {
    $_token_hash = { 
    "acl_master_token" => $token.chomp,
    "acl_token"        => $token.chomp,
    }
  } else {
    $_token_hash = {}
  }
  if ($use_puppet_pki == true) {
     if ($bootstrap == false) {
      file { "/etc/simp":
	ensure => directory,
      }
    }
    file { "/etc/simp/consul":
     ensure => directory,
    }
    if ($server == true) {
      $_cert_file_name = '/etc/simp/bootstrap/consul/server.dc1.consul.cert.pem'
      $_private_file_name = '/etc/simp/bootstrap/consul/server.dc1.consul.private.pem'
      $_ca_file_name = '/etc/simp/bootstrap/consul/ca.pem'
      if ($dont_copy_files == false) {
      file { "/etc/simp/bootstrap/":
	ensure => directory,
      }
      file { "/etc/simp/bootstrap/consul":
  	ensure => directory,
        }
        file { $_cert_file_name:
          content => file($_cert_file_name)
        }
        file { $_private_file_name:
          content => file($_private_file_name)
        }
        file { $_ca_file_name:
          content => file($_ca_file_name)
        }
        file { '/etc/simp/consul/cert.pem':
          content => file($_cert_file_name)
        }
        file { '/etc/simp/consul/key.pem':
          content => file($_private_file_name)
        }
        file { '/etc/simp/consul/ca.pem':
          content => file($_ca_file_name)
        }
      }
    } else {
      $_cert_file_name_source = "/etc/puppetlabs/puppet/ssl/certs/${::clientcert}.pem"
      $_ca_file_name_source = '/etc/puppetlabs/puppet/ssl/certs/ca.pem'
      $_private_file_name_source = "/etc/puppetlabs/puppet/ssl/private_keys/${::clientcert}.pem"
      file { '/etc/simp/consul/cert.pem':
        source => $_cert_file_name_source
      }
      file { '/etc/simp/consul/ca.pem':
        source => $_ca_file_name_source
      }
      file { '/etc/simp/consul/key.pem':
        source => $_key_file_name_source
      }
    }
    if ($bootstrap == false) {
      $_cert_hash = {
      "cert_file" => '/etc/simp/consul/cert.pem',
      "ca_file" => '/etc/simp/consul/ca.pem',
      "key_file" => '/etc/simp/consul/key.pem',
      }
    } else {
      $_cert_hash = {}
    }
  }
  # Attempt to store bootstrap info into consul directly via libkv.
  # Use softfail to get around issues if the service isn't up
  $hash = lookup('consul::config_hash', { "default_value" => {} })
  $class_hash =     {
    'server'           => $server,
    'node_name'        => $::hostname,
    'retry_join'       => [ $_serverhost ],
    'advertise_addr'   => $_advertise,
  }
  $merged_hash = $hash + $class_hash + $_datacenter + $config_hash + $_key_hash + $_token_hash + $_bootstrap_hash + $_cert_hash
  class { '::consul':
    config_hash          => $merged_hash,
    version => $version,
  }
}
