require 'spec_helper_acceptance'
require_relative 'ldap_test_configuration'
require_relative 'validate_ldap_entries'

test_name 'ldap_plugin using ldapi'

describe 'ldap_plugin using ldapi' do
  include_context('ldap test configuration')

  # Arbitrarily using the 389-DS instance configured with TLS.
  let(:ldap_instance_name) { 'simp_data_with_tls' }
  let(:ldap_instance) { ldap_instances[ldap_instance_name] }
  let(:ldap_uri) { "ldapi://%2fvar%2frun%2fslapd-#{ldap_instance_name}.socket" }
  let(:common_ldap_config) do
    {
      'type' => 'ldap',
   'ldap_uri'      => ldap_uri,
   'base_dn'       => ldap_instance[:simpkv_base_dn],
    }
  end

  # Command to run on the test host to clear out all stored key data.
  # - All stored in same 389-DS instance, so single clear command
  let(:clear_data_cmd) do
    [
      build_ldap_command('ldapdelete', common_ldap_config),
      '-r',
      %("ou=instances,#{ldap_instance[:simpkv_base_dn]}"),
    ].join(' ')
  end

  # simpkv::options hieradata for 3 distinct backends
  # - 2 use LDAPI with EXTERNAL SASL authentication
  # - 1 uses LDAPI with simple authentication
  let(:backend_hiera) do
    backend_configs = {
      id1 => common_ldap_config,
      id2 => common_ldap_config,
      id3 => common_ldap_config.merge({
                                        'admin_dn' => ldap_instance[:admin_dn],
        'admin_pw_file' => ldap_instance[:admin_pw_file]
                                      })
    }

    # will set each 'id' to its corresponding backend name, which
    # results in a unique tree for that backend name beneath the
    # simpkv tree in the 389-DS instance
    generate_backend_hiera(backend_configs)
  end

  hosts_with_role(hosts, 'ldap_server').each do |host|
    context "simpkv ldap plugin on #{host} using ldapi" do
      it_behaves_like 'a simpkv plugin test', host

      context 'LDAP-specific features' do
        let(:manifest) { %{simpkv::put('mykey', "Value for mykey", {})} }
        let(:get_ldap_attributes_cmd) do
          dn = "simpkvKey=mykey,ou=production,ou=environments,ou=default,ou=instances,#{ldap_instance[:simpkv_base_dn]}"
          [
            build_ldap_command('ldapsearch', common_ldap_config),
            '-o "ldif-wrap=no"',
            '-LLL',
            %(-b "#{dn}"),
            '+',
          ].join(' ')
        end

        it 'does not change LDAP modifyTimestamp when no changes are made' do
          # store a key and retrieve its LDAP modifyTimestamp
          set_hiera_and_apply_on(host, backend_hiera, manifest)
          result1 = on(host, get_ldap_attributes_cmd)
          timestamp1 = result1.stdout.split("\n").delete_if { |line| !line.start_with?('modifyTimestamp:') }.first

          # store a key with the same content and retrieve its LDAP modifyTimestamp
          set_hiera_and_apply_on(host, backend_hiera, manifest)
          result2 = on(host, get_ldap_attributes_cmd)
          timestamp2 = result2.stdout.split("\n").delete_if { |line| !line.start_with?('modifyTimestamp:') }.first

          # key was not modified, so timestamp should be the same
          expect(timestamp2).to eq(timestamp1)
        end
      end
    end
  end
end
