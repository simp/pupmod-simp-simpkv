
require 'spec_helper_acceptance'
require_relative 'ldap_test_configuration'

test_name 'simpkv client setup'

describe 'simpkv client setup' do
  include_context('ldap test configuration')

  # FIXME: Can't compile manifests with simpkv functions unless the files containing
  #       the admin passwords already exist on each host
  context 'Ensure LDAP password files for clients exists prior to using simpkv functions' do
    let(:manifest) do
      <<-EOM
      file { '/etc/simp': ensure => 'directory' }

      file { '#{ldap_instances['simp_data_without_tls'][:admin_pw_file]}':
          ensure  => present,
          owner   => 'root',
          group   => 'root',
          mode    => '0400',
          content => Sensitive('#{ldap_instances['simp_data_without_tls'][:admin_pw]}')
      }

      file { '#{ldap_instances['simp_data_with_tls'][:admin_pw_file]}':
          ensure  => present,
          owner   => 'root',
          group   => 'root',
          mode    => '0400',
          content => Sensitive('#{ldap_instances['simp_data_with_tls'][:admin_pw]}')
      }
      EOM
    end

    hosts.each do |host|
      it "creates admin pw files needed by ldap plugin on #{host}" do
        apply_manifest_on(host, manifest, catch_failures: true)
      end
    end
  end

  context 'Ensure openldap-clients package is installed on clients prior to using simpkv functions' do
    it 'installs openlap-clients package' do
      install_package_unless_present_on(hosts, 'openldap-clients')
    end
  end
end
