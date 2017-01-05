# == Class libkv::params
#
# This class is meant to be called from libkv.
# It sets variables according to platform.
#
class libkv::params {
  case $::osfamily {
    'RedHat': {
      $package_name = 'libkv'
      $service_name = 'libkv'
    }
    default: {
      fail("${::operatingsystem} not supported")
    }
  }
}
