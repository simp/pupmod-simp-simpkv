# Full description of SIMP module 'libkv' here.
#
# === Welcome to SIMP!
# This module is a component of the System Integrity Management Platform, a
# managed security compliance framework built on Puppet.
#
# ---
# *FIXME:* verify that the following paragraph fits this module's characteristics!
# ---
#
# This module is optimally designed for use within a larger SIMP ecosystem, but
# it can be used independently:
#
# * When included within the SIMP ecosystem, security compliance settings will
#   be managed from the Puppet server.
#
# * If used independently, all SIMP-managed security subsystems are disabled by
#   default, and must be explicitly opted into by administrators.  Please
#   review the +trusted_nets+ and +$enable_*+ parameters for details.
#
# @param service_name
#   The name of the libkv service
#
# @param package_name
#   The name of the libkv package
#
# @param trusted_nets
#   A whitelist of subnets (in CIDR notation) permitted access
#
# @param enable_auditing
#   If true, manage auditing for libkv
#
# @param enable_firewall
#   If true, manage firewall rules to acommodate libkv
#
# @param enable_logging
#   If true, manage logging configuration for libkv
#
# @param enable_pki
#   If true, manage PKI/PKE configuration for libkv
#
# @param enable_selinux
#   If true, manage selinux to permit libkv
#
# @param enable_tcpwrappers
#   If true, manage TCP wrappers configuration for libkv
#
# @author simp
#
class libkv (
  String $service_name                     = $::libkv::params::service_name,
  String $package_name                     = $::libkv::params::package_name,
  Simplib::Port $tcp_listen_port           = 9999,
  Array[String] $trusted_nets              = simplib::lookup('simp_options::trusted_nets', { 'default_value' => ['127.0.0.1/32'] }),
  Boolean $enable_pki                      = simplib::lookup('simp_options::pki', { 'default_value' => false }),
  Boolean $enable_auditing                 = simplib::lookup('simp_options::auditd', { 'default_value' => false }),
  Boolean $enable_firewall                 = simplib::lookup('simp_options::firewall', { 'default_value' => false }),
  Boolean $enable_logging                  = simplib::lookup('simp_options::syslog', { 'default_value' => false }),
  Boolean $enable_selinux                  = simplib::lookup('simp_options::selinux', { 'default_value' => false }),
  Boolean $enable_tcpwrappers              = simplib::lookup('simp_options::tcpwrappers', { 'default_value' => false })

) inherits ::libkv::params {

  include '::libkv::install'
  include '::libkv::config'
  include '::libkv::service'
  Class[ '::libkv::install' ] ->
  Class[ '::libkv::config'  ] ~>
  Class[ '::libkv::service' ] ->
  Class[ '::libkv' ]

  if $enable_pki {
    include '::libkv::config::pki'
    Class[ '::libkv::config::pki' ] ->
    Class[ '::libkv::service' ]
  }

  if $enable_auditing {
    include '::libkv::config::auditing'
    Class[ '::libkv::config::auditing' ] ->
    Class[ '::libkv::service' ]
  }

  if $enable_firewall {
    include '::libkv::config::firewall'
    Class[ '::libkv::config::firewall' ] ->
    Class[ '::libkv::service'  ]
  }

  if $enable_logging {
    include '::libkv::config::logging'
    Class[ '::libkv::config::logging' ] ->
    Class[ '::libkv::service' ]
  }

  if $enable_selinux {
    include '::libkv::config::selinux'
    Class[ '::libkv::config::selinux' ] ->
    Class[ '::libkv::service' ]
  }

  if $enable_tcpwrappers {
    include '::libkv::config::tcpwrappers'
    Class[ '::libkv::config::tcpwrappers' ] ->
    Class[ '::libkv::service' ]
  }
}
