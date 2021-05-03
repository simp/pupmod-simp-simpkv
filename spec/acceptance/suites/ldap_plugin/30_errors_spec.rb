require 'spec_helper_acceptance'
require_relative 'ldap_test_configuration'

test_name 'ldap_plugin errors'

describe 'ldap_plugin errors' do
  include_context('ldap test configuration')

  # The purpose of this test is twofold:
  # - Make sure typical configuration error cases cause compilation errors.
  # - Make sure the error message that pop out are useful!
  #
  # This test uses 2 389-DS instances (distinct LDAP servers) for testing
  # ldap_plugin errors related to communication with the LDAP servers
  # * LDAP instance that requires encryption (TLS or StartTLS)
  # * LDAP instance that does not allow encryption
  #
  let(:ldap_with_tls) { ldap_instances['simp_data_with_tls'] }
  let(:ldap_without_tls) { ldap_instances['simp_data_without_tls'] }

  # key will go to the default backend
  let(:manifest) { %Q{simpkv::put('mykey', "Value for mykey", {})} }
  let(:new_pki_certs_dir) { '/etc/pki/simp-testing-new' }

  context 'TLS error test prep' do
    it 'generates a second set of host PKI certificates' do
      # Generate and install new PKI certificates to a different directory
      # on each SUT
      # - Uses PKI-generation-infrastructure already available on the node
      #   with the default role
      server = only_host_with_role(hosts, 'default')
      host_dir = '/root/pki'
      on(server, "cd #{host_dir}; cat #{host_dir}/pki.hosts | xargs bash make.sh")

      Dir.mktmpdir do |cert_dir|
        scp_from(server, host_dir, cert_dir)
        hosts.each { |sut| copy_pki_to(sut, cert_dir, new_pki_certs_dir) }
      end
    end
  end

  hosts_with_role(hosts, 'ldap_server').each do |server|
    context "with LDAP servers on #{server}" do
      let(:server_fqdn) { fact_on(server, 'fqdn').strip }
      let(:valid_ldaps_uri)         { "ldaps://#{server_fqdn}:#{ldap_with_tls[:secure_port]}" }
      let(:valid_ldap_uri)          { "ldap://#{server_fqdn}:#{ldap_without_tls[:port]}" }
      let(:failed_regex)  {
        # The full failure message tells the user the ldapsearch command that failed
        # and its error messages, so that the user doesn't have to apply the manifest
        # with --debug to figure out what is going on!
        %r{Unable to construct 'ldap/default': Plugin could not access ou=simpkv,o=puppet,dc=simp.*ldapsearch}
      }

      hosts_with_role(hosts, 'client').each do |client|
        context "with LDAP client #{client}" do

          # valid backend config for ldap
          let(:valid_ldap_config) {{
            'type'          => 'ldap',
            'ldap_uri'      => valid_ldap_uri,
            'base_dn'       => ldap_without_tls[:simpkv_base_dn],
            'admin_dn'      => ldap_without_tls[:admin_dn],
            'admin_pw_file' => ldap_without_tls[:admin_pw_file]
          }}


          context 'with LDAP configuration errors' do
            it 'fails to compile when LDAP URI has invalid host' do
              bad_uri = 'ldap://oops.test.local'
              invalid_config = valid_ldap_config.merge({ 'ldap_uri' => bad_uri })
              backend_configs = { 'default' => invalid_config }
              backend_hiera = generate_backend_hiera(backend_configs)

              result = set_hiera_and_apply_on(client, backend_hiera, manifest,
                { :expect_failures => true } )

              expect( result.stderr ).to match(failed_regex)
            end

            it 'fails to compile when LDAP URI has invalid port' do
              # Our simpkv LDAP servers are intentionally not on the standard
              # port (389) for LDAP, because they do not contain accounts data.
              bad_uri =  "ldap://#{server_fqdn}:389"
              invalid_config = valid_ldap_config.merge({ 'ldap_uri' => bad_uri })
              backend_configs = { 'default' => invalid_config }
              backend_hiera = generate_backend_hiera(backend_configs)

              result =set_hiera_and_apply_on(client, backend_hiera, manifest,
                { :expect_failures => true } )

              expect( result.stderr ).to match(failed_regex)
            end

            it 'fails to compile when base DN is invalid' do
              bad_base_dn =  valid_ldap_config['base_dn'] + ',dc=oops'
              invalid_config = valid_ldap_config.merge({ 'base_dn' => bad_base_dn })
              backend_configs = { 'default' => invalid_config }
              backend_hiera = generate_backend_hiera(backend_configs)

              result = set_hiera_and_apply_on(client, backend_hiera, manifest,
                { :expect_failures => true } )

              expect( result.stderr ).to match(failed_regex)
            end

            it 'fails to compile when admin DN is invalid' do
              bad_admin_dn =  valid_ldap_config['admin_dn'] + ',dc=oops'
              invalid_config = valid_ldap_config.merge({ 'admin_dn' => bad_admin_dn })
              backend_configs = { 'default' => invalid_config }
              backend_hiera = generate_backend_hiera(backend_configs)

              result = set_hiera_and_apply_on(client, backend_hiera, manifest,
                { :expect_failures => true } )

              expect( result.stderr ).to match(failed_regex)
            end

            it 'fails to compile when admin password is invalid' do
              # create a password file that has the right permissions but wrong content
              bad_admin_pw_file = '/root/wrong_admin_password.txt'
              on(client, "echo wrong_admin_password > #{bad_admin_pw_file}")
              on(client, "chmod 600 #{bad_admin_pw_file}")

              invalid_config = valid_ldap_config.merge({ 'admin_pw_file' => bad_admin_pw_file })
              backend_configs = { 'default' => invalid_config }
              backend_hiera = generate_backend_hiera(backend_configs)

              result = set_hiera_and_apply_on(client, backend_hiera, manifest,
                { :expect_failures => true } )

              expect( result.stderr ).to match(failed_regex)
            end

            it 'fails to compile when TLS certs are invalid' do
              # client is using different certs than the LDAP server knows about!
              client_fqdn =  fact_on(client, 'fqdn').strip
              tls_cert    =  "#{new_pki_certs_dir}/public/#{client_fqdn}.pub"
              tls_key     =  "#{new_pki_certs_dir}/private/#{client_fqdn}.pem"
              tls_cacert  =  "#{new_pki_certs_dir}/cacerts/cacerts.pem"

              invalid_config = {
                'type'          => 'ldap',
                'ldap_uri'      => valid_ldaps_uri,
                'base_dn'       => ldap_with_tls[:simpkv_base_dn],
                'admin_dn'      => ldap_with_tls[:admin_dn],
                'admin_pw_file' => ldap_with_tls[:admin_pw_file],
                'tls_cert'      => tls_cert,
                'tls_key'       => tls_key,
                'tls_cacert'    => tls_cacert,
              }

              backend_configs = { 'default' => invalid_config }
              backend_hiera = generate_backend_hiera(backend_configs)

              result = set_hiera_and_apply_on(client, backend_hiera, manifest,
                { :expect_failures => true } )

              expect( result.stderr ).to match(failed_regex)
            end
          end
        end
      end
    end
  end
end
