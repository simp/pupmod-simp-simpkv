# frozen_string_literal: true

require 'spec_helper_acceptance'
require_relative 'ldap_test_configuration'

test_name 'ldap server setup'

describe 'ldap server setup' do
  include_context('ldap test configuration')
  let(:bootstrap_ldif) { File.read(File.join(__dir__, 'files', 'bootstrap.ldif')) }

  hosts.each do |host|
    context "host set up on #{host}" do
      it 'has a proper FQDN' do
        on(host, "hostname #{fact_on(host, 'fqdn')}")
        on(host, 'hostname -f > /etc/hostname')
      end
    end
  end

  # FIXMEs
  # - This test does not yet use a SIMP profile to set up the simp_data LDAP
  #   instance.
  # - This test manually works around the lack of schema management in
  #   simp/ds389 (SIMP-9676).
  # - This test does not set an ACI in the simp_data LDAP instance that would
  #   allow the puppet user to access the instance via without a password.
  #
  hosts_with_role(hosts, 'ldap_server').each do |host|
    context "LDAP server set up on #{host}" do
      let(:manifest) do
        'include ds389'
      end

      let(:hieradata) do
        {
          'ds389::instances' => {
            'simp_data_without_tls' => {
              'base_dn'                => ldap_instances['simp_data_without_tls'][:base_dn],
              'root_dn'                => ldap_instances['simp_data_without_tls'][:root_dn],
              'root_dn_password'       => ldap_instances['simp_data_without_tls'][:root_pw],
              'listen_address'         => '0.0.0.0',
              'port'                   => ldap_instances['simp_data_without_tls'][:port],
              'bootstrap_ldif_content' => bootstrap_ldif,
            },

            'simp_data_with_tls' => {
              'base_dn'                => ldap_instances['simp_data_with_tls'][:base_dn],
              'root_dn'                => ldap_instances['simp_data_with_tls'][:root_dn],
              'root_dn_password'       => ldap_instances['simp_data_with_tls'][:root_pw],
              'listen_address'         => '0.0.0.0',
              'port'                   => ldap_instances['simp_data_with_tls'][:port],
              'secure_port'            => ldap_instances['simp_data_with_tls'][:secure_port],
              'bootstrap_ldif_content' => bootstrap_ldif,
              'enable_tls'             => true,
              'tls_params'             => {
                'source' => certdir,
              },
            },
          },
        }
      end

      it 'disables firewall for LDAP access via custom ports' do
        # FIXME: ds389 module does NOT manage firewall rules. So, for hosts that
        # have firewalld running by default, we need to make sure it is stopped
        # or add our own rules. This should be a non-issue when SIMP provides
        # a 389-DS instance for simpkv in the simp_ds389 module.
        on(host, 'puppet resource service firewalld ensure=stopped')
      end

      it 'works with no errors' do
        set_hieradata_on(host, hieradata)
        apply_manifest_on(host, manifest, catch_failures: true)
      end

      it 'is idempotent' do
        apply_manifest_on(host, manifest, catch_changes: true)
      end

      it "applies a simpkv custom schema to all 389-DS instances on #{host}" do
        ldap_instances.each do |instance, config|
          src = File.join(__dir__, 'files', '70simpkv.ldif')
          dest = "/etc/dirsrv/slapd-#{instance}/schema/70simpkv.ldif"
          scp_to(host, src, dest)
          on(host, "chown dirsrv:dirsrv #{dest}")
          # FIXME: use dsconf schema reload instead
          on(host, %(schema-reload.pl -Z #{instance} -D "#{config[:root_dn]}" -w "#{config[:root_pw]}" -P LDAPI))
          on(host, "egrep 'ERR\s*-\s*schemareload' /var/log/dirsrv/slapd-#{instance}/errors",
            acceptable_exit_codes: [1])
        end
      end
    end
  end
end
