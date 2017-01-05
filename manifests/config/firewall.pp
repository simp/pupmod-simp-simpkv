# == Class libkv::config::firewall
#
# This class is meant to be called from libkv.
# It ensures that firewall rules are defined.
#
class libkv::config::firewall {
  assert_private()

  # FIXME: ensure your module's firewall settings are defined here.
  iptables::listen::tcp_stateful{ 'allow_libkv_tcp_connections':
    trusted_nets => $::libkv::trusted_nets,
    dports       => $::libkv::tcp_listen_port
  }
}
