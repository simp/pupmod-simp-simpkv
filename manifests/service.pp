# == Class libkv::service
#
# This class is meant to be called from libkv.
# It ensure the service is running.
#
class libkv::service {
  assert_private()

  service { $::libkv::service_name:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true
  }
}
