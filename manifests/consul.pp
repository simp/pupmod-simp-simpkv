# == Class libkv::consul
# vim: set expandtab ts=2 sw=2:
#
# This class uses solarkennedy/consul to initialize .
#
class libkv::consul(
  $server = false,
  $bootstrap = false,
  $key = undef,
  $version = '0.7.4',
  $client_addr = '0.0.0.0',
) {
  package { "unzip": }
  if ($bootstrap == true) {
    $bootstrap_expect = 1
  }
  class { '::consul':
    config_hash          => {
      'data_dir'         => '/opt/consul',
      'bootstrap_expect' => $bootstrap_expect,
      'server'           => $server,
      'node_name'        => $::hostname,
      'retry_join'       => [ $serverip ],
      'advertise_addr'   => $::ipaddress,
      'client_addr'      => $client_addr,
      'ui_dir'           => '/opt/consul/ui',
    },
    version => $version,
  }
}
