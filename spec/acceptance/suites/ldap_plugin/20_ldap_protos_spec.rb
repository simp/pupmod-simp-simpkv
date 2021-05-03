require 'spec_helper_acceptance'
require_relative 'ldap_test_configuration'

test_name 'ldap_plugin using unencrypted and encrypted LDAP'

describe 'ldap_plugin using unencrypted and encrypted LDAP' do
  include_context('ldap test configuration')

  # This test uses 2 389-DS instances (distinct LDAP servers) for 3 simpkv
  # backends:
  # * LDAP instance that requires encryption is used for 2 simpkv backends:
  #   - simpkv backend communicating via TLS
  #   - simpkv backend communicating via StartTLS
  # * LDAP instance that does not allow encryption is used as 1 simpkv backend.
  #
  let(:ldap_with_tls) { ldap_instances['simp_data_with_tls'] }
  let(:ldap_without_tls) { ldap_instances['simp_data_without_tls'] }

  hosts_with_role(hosts, 'ldap_server').each do |server|
    context "with LDAP servers on #{server}" do
      let(:server_fqdn) { fact_on(server, 'fqdn').strip }
      let(:ldaps_uri)         { "ldaps://#{server_fqdn}:#{ldap_with_tls[:secure_port]}" }
      let(:ldap_starttls_uri) { "ldap://#{server_fqdn}:#{ldap_with_tls[:port]}" }
      let(:ldap_uri)          { "ldap://#{server_fqdn}:#{ldap_without_tls[:port]}" }

      hosts_with_role(hosts, 'client').each do |client|
        context "with LDAP client #{client}" do
          let(:client_fqdn) { fact_on(client, 'fqdn').strip }
          let(:tls_cert)   { "#{certdir}/public/#{client_fqdn}.pub" }
          let(:tls_key)    { "#{certdir}/private/#{client_fqdn}.pem" }
          let(:tls_cacert) { "#{certdir}/cacerts/cacerts.pem" }
          let(:ldaps_config) {{
            'type'          => 'ldap',
            'ldap_uri'      => ldaps_uri,
            'base_dn'       => ldap_with_tls[:simpkv_base_dn],
            'admin_dn'      => ldap_with_tls[:admin_dn],
            'admin_pw_file' => ldap_with_tls[:admin_pw_file],
            'tls_cert'      => tls_cert,
            'tls_key'       => tls_key,
            'tls_cacert'    => tls_cacert,
          }}

          let(:ldap_starttls_config) {{
            'type'          => 'ldap',
            'ldap_uri'      => ldap_starttls_uri,
            'base_dn'       => ldap_with_tls[:simpkv_base_dn],
            'admin_dn'      => ldap_with_tls[:admin_dn],
            'admin_pw_file' => ldap_with_tls[:admin_pw_file],
            'enable_tls'    => true,
            'tls_cert'      => tls_cert,
            'tls_key'       => tls_key,
            'tls_cacert'    => tls_cacert,
          }}

          let(:ldap_config) {{
            'type'          => 'ldap',
            'ldap_uri'      => ldap_uri,
            'base_dn'       => ldap_without_tls[:simpkv_base_dn],
            'admin_dn'      => ldap_without_tls[:admin_dn],
            'admin_pw_file' => ldap_without_tls[:admin_pw_file]
          }}

          # Command to run on the test host to clear out all stored key data.
          let(:clear_data_cmd) {
            [
              build_ldap_command('ldapdelete', ldaps_config),
              '-r',
              %Q{"ou=instances,#{ldap_with_tls[:simpkv_base_dn]}"},
              ' ; ',

              build_ldap_command('ldapdelete', ldap_config),
              '-r',
              %Q{"ou=instances,#{ldap_without_tls[:simpkv_base_dn]}"},
            ].join(' ')
          }

          # simpkv::options hieradata for 3 distinct backends
          let(:backend_hiera) {
            backend_configs = {
              id1 => ldaps_config,
              id2 => ldap_starttls_config,
              id3 => ldap_config
            }

            # will set each 'id' to its corresponding backend name, which
            # results in unique trees for that backend name beneath the
            # simpkv tree in the 389-DS instances
            generate_backend_hiera(backend_configs)
          }

          context "simpkv ldap_plugin on #{client} using ldap with & without TLS to #{server}" do
            it_behaves_like 'a simpkv plugin test', client
          end
        end
      end
    end
  end
end
