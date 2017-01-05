# == Class libkv::install
#
# This class is called from libkv for install.
#
class libkv::install {
  assert_private()

  package { $::libkv::package_name:
    ensure => present
  }
}
