# Common configuration for the ldap plugin test
#
# * LDAP configuration needed to set up and access the LDAP
#   instances containing simpkv data.
#   - One instance will be TLS enabled and the other will not.
#
# * Context for 'a simpkv plugin test' shared_examples
# * Methods from Acceptance::Helpers::LdapUtils that the LDAP tests use
#   to build their respective keystore clear data commands
#
require 'acceptance/helpers/ldap_utils'
require_relative 'validate_ldap_entries'

shared_context 'ldap test configuration' do
  include Acceptance::Helpers::LdapUtils

  # TODO: Create a separate administrator bind DN and configure it appropriately
  #      for LDAPI via an ACI
  # - This test configures the ldap_plugin to use the appropriate instance root
  #   dn and password as its admin user, instead of a specific simpkv admin
  #   user and password for the simpkv subtree within the instance.
  # - The 'simp' 389-DS instances do not have an ACI set up for account-to-DN
  #   mapping for the 'root' user.
  #
  let(:base_dn) { 'dc=simp' }
  let(:root_dn) { 'cn=Directory_Manager' }
  let(:simpkv_base_dn) { "ou=simpkv,o=puppet,#{base_dn}" }
  let(:admin_dn) { root_dn }

  let(:ldap_instances) do
    {
      'simp_data_without_tls' => {
        # ds389::instance config
        base_dn: base_dn,
        root_dn: root_dn,
        root_pw: 'P@ssw0rdP@ssw0rd!N0TLS',
        port: 387,

        # simpkv ldap_plugin config
        simpkv_base_dn: simpkv_base_dn,
        admin_dn: admin_dn,
        admin_pw: 'P@ssw0rdP@ssw0rd!N0TLS',
        admin_pw_file: '/etc/simp/simp_data_without_tls_pw.txt',
      },

    'simp_data_with_tls' => {
      # ds389::instance config
      base_dn: base_dn,
      root_dn: root_dn,
      root_pw: 'P@ssw0rdP@ssw0rd!TLS',
      port: 388, # for StartTLS
      secure_port: 637,

      # simpkv ldap_plugin config
      simpkv_base_dn: simpkv_base_dn,
      admin_dn: admin_dn,
      admin_pw: 'P@ssw0rdP@ssw0rd!TLS',
      admin_pw_file: '/etc/simp/simp_data_with_tls_pw.txt',
    }
    }
  end

  # PKI general
  let(:certdir) { '/etc/pki/simp-testing/pki' }

  # Context for 'a simpkv plug test' shared_examples

  # Method object to validate key/folder entries in an LDAP instance
  # - Conforms to the API specified in 'a simpkv plugin test' shared_examples
  let(:validator) { method(:validate_ldap_entries) }

  # The ids below are the backend/app_id names used in the test:
  # - One must be 'default' or simpkv::options validation will fail.
  # - 'a simpkv plugin test' shared_examples assumes there is a one-to-one
  #    mapping of the app_ids in the input key data to the backend names.
  #    Although simpkv supports fuzzy logic for that mapping, we set the
  #    backend names/app_ids to the same values, here, for simplicity. The
  #    fuzzy mapping logic is tested in the unit test.
  # - The input-data-generator currently supports exactly 3 app_ids.
  # - 'default' app_id is mapped to '' in the generated input key data, which, in
  #   turn causes simpkv functions to be called in the test manifests without
  #   an app_id set.  In other words, 'default' maps to the expected, normal
  #   usage of simpkv functions.
  #
  let(:id1) { 'default' }
  let(:id2) { 'custom' }
  let(:id3) { 'custom_snowflake' }

  # Hash of initial key information for the 3 test backends/app_ids.
  #
  # 'a simpkv plugin test' uses this data to test key storage operations
  # and then transform the data into subsets that it uses to test key/folder
  # existence, folder lists, and key and folder delete operations.
  let(:initial_key_info) do
    generate_initial_key_info(id1, id2, id3)
  end
end
