require 'spec_helper_acceptance'
require_relative '../ldap_plugin/ldap_test_configuration'
require_relative 'validate_multiple_plugins_entries'

test_name 'multiple plugins'

# This test verifies that the simpkv API supports the use of different plugins
# simultaneously. It uses 1 file plugin instance and 2 ldap plugin instances.
# The ldap plugins are configured to use different 389-DS instances (LDAP
# servers).
#
# Without a running puppetserver, the file plugin only works when the
# file keystore is on the test host on which manifests are being compiled. So,
# for test simplicity, we will have also have the LDAP keystores on the test
# host and we will use LDAPI to communicate with the LDAP servers.

describe 'multiple plugins' do
  # We will use the LDAP instances configuration, id1, id2, id3, and
  # initial_key_info defined in this context, but override the validator
  # with one that handles both file and LDAP backends
  include_context('ldap test configuration')

  let(:file_backend_config) {{
    'type'      => 'file',
    'root_path' => "/var/simp/simpkv/file/#{id1}"
  }}

  let(:file_clear_data_cmd) { 'rm -rf /var/simp/simpkv/file' }

  let(:ldap1_name) { 'simp_data_with_tls' }
  let(:ldap1) { ldap_instances[ldap1_name] }
  let(:ldap1_uri) { "ldapi://%2fvar%2frun%2fslapd-#{ldap1_name}.socket" }
  let(:ldap1_backend_config) {{
    'type'          => 'ldap',
    'ldap_uri'      => ldap1_uri,
    'base_dn'       => ldap1[:simpkv_base_dn],
    'admin_dn'      => ldap1[:admin_dn],
    'admin_pw_file' => ldap1[:admin_pw_file]
  }}

  let(:ldap1_clear_data_cmd) {
    [
      build_ldap_command('ldapdelete', ldap1_backend_config),
      '-r',
      %Q{"ou=instances,#{ldap1[:simpkv_base_dn]}"}
    ].join(' ')
  }

  let(:ldap2_name) { 'simp_data_without_tls' }
  let(:ldap2) { ldap_instances[ldap2_name] }
  let(:ldap2_uri) { "ldapi://%2fvar%2frun%2fslapd-#{ldap2_name}.socket" }
  let(:ldap2_backend_config) {{
    'type'          => 'ldap',
    'ldap_uri'      => ldap2_uri,
    'base_dn'       => ldap2[:simpkv_base_dn],
    'admin_dn'      => ldap2[:admin_dn],
    'admin_pw_file' => ldap2[:admin_pw_file]
  }}

  let(:ldap2_clear_data_cmd) {
    [
      build_ldap_command('ldapdelete', ldap2_backend_config),
      '-r',
      %Q{"ou=instances,#{ldap2[:simpkv_base_dn]}"}
    ].join(' ')
  }

  # Command to run on the test host to clear out all stored key data.
  let(:clear_data_cmd) {
    [
      file_clear_data_cmd,
      ldap1_clear_data_cmd,
      ldap2_clear_data_cmd
    ].join(' ; ')
  }

  let(:backend_hiera) {
    backend_configs = {
      id1 => file_backend_config,
      id2 => ldap1_backend_config,
      id3 => ldap2_backend_config
    }

    generate_backend_hiera(backend_configs)
  }

  hosts.each do |host|
    context "with LDAP and file keystores on #{host}" do
      # Method object to validate key/folder entries in a file or LDAP instance
      # - Conforms to the API specified in 'a simpkv plugin test' shared_examples
      # - Defined here to override validator pulled in when we included the
      #   'ldap test configuration' context
      let(:validator) { method(:validate_multiple_plugin_entries) }

      it_behaves_like 'a simpkv plugin test', host
    end
  end
end
