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
  $serverip = $::serverip,
  $advertise = $::ipaddress
) {
  package { "unzip": }
  if ($bootstrap == true) {
    $bootstrap_expect = 1
  }
  $keypath = '/etc/simp/bootstrap/consul/key'
  $master_token_path = '/etc/simp/bootstrap/consul/master_token'
  if ($server == true) {
    $cert_file_name = '/etc/simp/bootstrap/consul/server.dc1.consul.cert.pem'
    $private_file_name = '/etc/simp/bootstrap/consul/server.dc1.consul.private.pem'
    $ca_file_name = '/etc/simp/bootstrap/consul/ca.pem'
  }
  if ($dont_copy_files == false) {
    file { $cert_file_name:
      content => file($cert_file_name)
    }
    file { $private_file_name:
      content => file($private_file_name)
    }
    file { $ca_file_name:
      content => file($ca_file_name)
    }
  }
  $hash = lookup('consul::config_hash', { "default_value" => {} })
  $class_hash =     {
    'data_dir'         => '/opt/consul',
    'bootstrap_expect' => $bootstrap_expect,
    'server'           => $server,
    'node_name'        => $::hostname,
    'retry_join'       => [ $serverip ],
    'advertise_addr'   => $advertise,
    'ui_dir'           => '/opt/consul/ui',
  }
  $merged_hash = $hash.merge($class_hash)
  notify { "hash = $hash": }
  class { '::consul':
    config_hash          => $merged_hash,
    version => $version,
  }
}
