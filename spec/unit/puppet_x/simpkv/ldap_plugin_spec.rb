require 'spec_helper'

require 'fileutils'
require 'tmpdir'

# mimic loading that is done in simpkv.rb
project_dir = File.join(File.dirname(__FILE__), '..', '..', '..', '..')
plugin_file = File.join(project_dir, 'lib', 'puppet_x', 'simpkv', 'ldap_plugin.rb')
plugin_class = nil
obj = Object.new
obj.instance_eval(File.read(plugin_file), plugin_file)

###############################################################################
# The ldap plugin is significantly tested in its acceptance test So, the
# testing here is largely for code paths not otherwise tested.
###############################################################################

describe 'simpkv ldap plugin anonymous class' do
  before(:each) do
    @tmpdir = Dir.mktmpdir
    @admin_pw_file = File.join(@tmpdir, 'admin_pw.txt')
    File.open(@admin_pw_file, 'w') { |file| file.puts('P@ssw0rdP@ssw0rd!') }
    @options = {
      'backends' => {
        'default' => {
          'id'            => 'default',
          'type'          => 'ldap',
          'ldap_uri'      => 'ldapi://simpkv.ldap.example.com',
        },
        'unencrypted' => {
          'id'            => 'unencrypted',
          'type'          => 'ldap',
          'ldap_uri'      => 'ldap://simpkv.ldap.example.com',
          'admin_pw_file' => @admin_pw_file,
        },
        'starttls' => {
          'id'            => 'starttls',
          'type'          => 'ldap',
          'ldap_uri'      => 'ldap://simpkv.ldap.example.com',
          'admin_pw_file' => @admin_pw_file,
          'enable_tls'    => true,
          'tls_cert'      => '/certdir/public/client.example.com.pub',
          'tls_key'       => '/certdir/private/client.example.com.pem',
          'tls_cacert'    => '/certdir/cacerts/cacerts.pem',
        },
        'tls' => {
          'id'            => 'tls',
          'type'          => 'ldap',
          'ldap_uri'      => 'ldaps://simpkv.ldap.example.com',
          'admin_pw_file' => @admin_pw_file,
          'tls_cert'      => '/certdir/public/client.example.com.pub',
          'tls_key'       => '/certdir/private/client.example.com.pem',
          'tls_cacert'    => '/certdir/cacerts/cacerts.pem',
        },
      },
    }
  end

  after(:each) do
    FileUtils.remove_entry_secure(@tmpdir)
  end

  # DNs here assume production environment keys and default backend
  let(:key)           { 'environments/production/mykey' }
  let(:base_key)      { File.basename(key) }
  let(:full_key_path) { "instances/default/#{key}" }
  let(:production_dn) { 'ou=production,ou=environments,ou=default,ou=instances,ou=simpkv,o=puppet,dc=simp' }
  let(:key_dn)        { "simpkvKey=#{base_key},#{production_dn}" }
  let(:value)         { 'myvalue' }
  let(:stored_value)  { %({"value":"#{value}","metadata":{}}) }

  let(:folder)           { 'environments/production/myfolder' }
  let(:base_folder)      { File.basename(folder) }
  #  let(:full_folder_path) { "instances/default/#{folder}" }
  let(:folder_dn)        { "ou=#{base_folder},#{production_dn}" }

  let(:ldap_busy_response) do
    {
      success: false,
    exitstatus: 51,
    stdout: '',
    stderr: 'ldapxxx failed:\nServer busy',
    }
  end

  let(:ldap_no_such_object_response) do
    {
      success: false,
    exitstatus: 32,
    stdout: '',
    stderr: 'No such object',
    }
  end

  let(:ldap_other_error_response) do
    {
      success: false,
    exitstatus: 1,
    stdout: '',
    stderr: 'ldapxxx failed:\nOther error',
    }
  end

  # success response from run_command for which we only care about
  # :success or :exitstatus
  let(:success_response_simple) { { success: true, exitstatus: 0 } }

  context '#initialize' do
    it 'is expected to set name' do
      plugin_name = 'ldap/test'
      plugin = plugin_class.new(plugin_name)
      expect(plugin.name).to eq plugin_name
    end
  end

  # See parse_config tests for other permutations of valid and invalid config
  context '#configure' do
    before(:each) do
      @plugin = plugin_class.new('ldap/default')
    end

    it 'succeeds using valid config' do
      options = @options.merge({ 'backend' => 'default' })

      expect(@plugin).to receive(:set_base_ldap_commands)
      expect(@plugin).to receive(:verify_ldap_access)
      expect(@plugin).to receive(:ensure_instance_tree)
      expect { @plugin.configure(options) }.not_to raise_error
    end

    context 'error cases' do
      it 'fails when options is not a Hash' do
        expect { @plugin.configure('oops') }
          .to raise_error(%r{Plugin misconfigured})
      end

      it "fails when options missing 'backend' key" do
        expect { @plugin.configure({}) }
          .to raise_error(%r{Plugin misconfigured})
      end

      it "fails when options missing 'backends' key" do
        options = { 'backend' => 'test' }
        expect { @plugin.configure(options) }
          .to raise_error(%r{Plugin misconfigured: {.*backend.*}})
      end

      it "fails when options 'backends' key is not a Hash" do
        options = {
          'backend'  => 'test',
          'backends' => 'oops',
        }
        expect { @plugin.configure(options) }
          .to raise_error(%r{Plugin misconfigured})
      end

      it "fails when options 'backends' does not have the specified backend" do
        options = {
          'backend'  => 'test',
          'backends' => {
            'test1' => { 'id' => 'test', 'type' => 'file' },
          },
        }
        expect { @plugin.configure(options) }
          .to raise_error(%r{Plugin misconfigured})
      end

      it "fails when the correct 'backends' element has no 'id' key" do
        options = {
          'backend' => 'test',
          'backends' => {
            'test1' => { 'id' => 'test', 'type' => 'file' },
            'test' => {},
          },
        }

        expect { @plugin.configure(options) }
          .to raise_error(%r{Plugin misconfigured})
      end

      it "fails when the correct 'backends' element has no 'type' key" do
        options = {
          'backend'  => 'test',
          'backends' => {
            'test1' => { 'id' => 'test', 'type' => 'file' },
            'test'  => { 'id' => 'test' },
          },
        }
        expect { @plugin.configure(options) }
          .to raise_error(%r{Plugin misconfigured})
      end

      it "fails when the correct 'backends' element has wrong 'type' value" do
        options = {
          'backend'  => 'test',
          'backends' => {
            'test1' => { 'id' => 'test', 'type' => 'file' },
            'test'  => { 'id' => 'test', 'type' => 'file' },
          },
        }
        expect { @plugin.configure(options) }
          .to raise_error(%r{Plugin misconfigured})
      end
    end
  end

  context 'public API' do
    before(:each) do
      @plugin = plugin_class.new('ldap/default')
    end

    context 'when public API called before configure' do
      it '#delete should return failure' do
        result = @plugin.delete(key)
        expect(result[:result]).to be false
        expect(result[:err_msg]).to eq 'Internal error: delete called before configure'
      end

      it '#deletetree should return failure' do
        result = @plugin.deletetree(folder)
        expect(result[:result]).to be false
        expect(result[:err_msg]).to eq 'Internal error: deletetree called before configure'
      end

      it '#exists should return failure' do
        result = @plugin.exists(key)
        expect(result[:result]).to be_nil
        expect(result[:err_msg]).to eq 'Internal error: exists called before configure'
      end

      it '#get should return failure' do
        result = @plugin.get(key)
        expect(result[:result]).to be_nil
        expect(result[:err_msg]).to eq 'Internal error: get called before configure'
      end

      it '#list should return failure' do
        result = @plugin.list(folder)
        expect(result[:result]).to be_nil
        expect(result[:err_msg]).to eq 'Internal error: list called before configure'
      end

      it '#put should return failure' do
        result = @plugin.put(key, value)
        expect(result[:result]).to be false
        expect(result[:err_msg]).to eq 'Internal error: put called before configure'
      end
    end

    context 'after configure' do
      before(:each) do
        options = @options.merge({ 'backend' => 'default' })
        expect(Facter::Core::Execution).to receive(:which).with('ldapadd').and_return('/usr/bin/ldapadd')
        expect(Facter::Core::Execution).to receive(:which).with('ldapdelete').and_return('/usr/bin/ldapdelete')
        expect(Facter::Core::Execution).to receive(:which).with('ldapmodify').and_return('/usr/bin/ldapmodify')
        expect(Facter::Core::Execution).to receive(:which).with('ldapsearch').and_return('/usr/bin/ldapsearch')
        expect(@plugin).to receive(:verify_ldap_access)
        expect(@plugin).to receive(:ensure_instance_tree)
        @plugin.configure(options)
      end

      describe '#delete' do
        it 'returns success when retries succeed' do
          # ldapdelete will return busy code first time and then success
          expect(@plugin).to receive(:run_command).with(%r{ldapdelete})
                                                  .and_return(ldap_busy_response, success_response_simple)

          result = @plugin.delete(key)
          expect(result[:result]).to be true
          expect(result[:err_msg]).to be_nil
        end

        it 'returns failure when retries fail' do
          # ldapdelete will return busy code both times
          expect(@plugin).to receive(:run_command).with(%r{ldapdelete})
                                                  .and_return(ldap_busy_response, ldap_busy_response)

          result = @plugin.delete(key)
          expect(result[:result]).to be false
          expect(result[:err_msg]).to eq(ldap_busy_response[:stderr])
        end

        it 'returns failure when other ldapdelete failure occurs' do
          expect(@plugin).to receive(:run_command).with(%r{ldapdelete})
                                                  .and_return(ldap_other_error_response)

          result = @plugin.delete(key)
          expect(result[:result]).to be false
          expect(result[:err_msg]).to eq(ldap_other_error_response[:stderr])
        end
      end

      describe '#deletetree' do
        it 'removes the folder tree from the intenral set of existing folders upon success' do
          @plugin.existing_folders.add('instances/default/globals/app1')
          @plugin.existing_folders.add('instances/default/globals/app1/group1')
          @plugin.existing_folders.add('instances/default/globals/app1/group1/user1')
          @plugin.existing_folders.add('instances/default/globals/app1/group2/user1')
          @plugin.existing_folders.add('instances/default/globals/app2')

          expect(@plugin).to receive(:run_command).with(%r{ldapdelete})
                                                  .and_return(success_response_simple)

          result = @plugin.deletetree('globals/app1')
          expect(result[:result]).to be true
          expect(result[:err_msg]).to be_nil

          expected_folders = Set.new
          expected_folders.add('instances/default/globals/app2')
          expect(@plugin.existing_folders).to eq(expected_folders)
        end

        it 'returns success when retries succeed' do
          # ldapdelete will return busy code first time and then success
          expect(@plugin).to receive(:run_command).with(%r{ldapdelete})
                                                  .and_return(ldap_busy_response, success_response_simple)

          result = @plugin.deletetree(folder)
          expect(result[:result]).to be true
          expect(result[:err_msg]).to be_nil
        end

        it 'returns failure when retries fail' do
          # ldapdelete will return busy code both times
          expect(@plugin).to receive(:run_command).with(%r{ldapdelete})
                                                  .and_return(ldap_busy_response, ldap_busy_response)

          result = @plugin.deletetree(folder)
          expect(result[:result]).to be false
          expect(result[:err_msg]).to eq(ldap_busy_response[:stderr])
        end

        it 'returns failure when other ldapdelete failure occurs' do
          expect(@plugin).to receive(:run_command).with(%r{ldapdelete})
                                                  .and_return(ldap_other_error_response)

          result = @plugin.deletetree(folder)
          expect(result[:result]).to be false
          expect(result[:err_msg]).to eq(ldap_other_error_response[:stderr])
        end
      end

      describe '#exists' do
        let(:success_response_dn_match) do
          {
            success: true,
         exitstatus: 0,
         stdout: "dn: #{key_dn}",
          }
        end

        it 'returns success when retries succeed' do
          # ldapsearch will return busy code first time and then success
          expect(@plugin).to receive(:run_command).with(%r{ldapsearch})
                                                  .and_return(ldap_busy_response, success_response_dn_match)

          result = @plugin.exists(key)
          expect(result[:result]).to be true
          expect(result[:err_msg]).to be_nil
        end

        it 'returns failure when retries fail' do
          # ldapsearch will return busy code both times
          expect(@plugin).to receive(:run_command).with(%r{ldapsearch})
                                                  .and_return(ldap_busy_response, ldap_busy_response)

          result = @plugin.exists(key)
          expect(result[:result]).to be_nil
          expect(result[:err_msg]).to eq(ldap_busy_response[:stderr])
        end

        it 'returns failure when other ldapsearch failure occurs' do
          expect(@plugin).to receive(:run_command).with(%r{ldapsearch})
                                                  .and_return(ldap_other_error_response)

          result = @plugin.exists(key)
          expect(result[:result]).to be_nil
          expect(result[:err_msg]).to eq(ldap_other_error_response[:stderr])
        end
      end

      describe '#get' do
        let(:success_response_simpkvKey) do
          {
            success: true,
         exitstatus: 0,
         stdout: <<~EOM,
           dn: #{key_dn}
           objectClass: simpkvEntry
           objectClass: top
           simpkvKey: #{base_key}
           simpkvJsonValue: #{stored_value}
          EOM
          }
        end

        it 'returns success when retries succeed' do
          # ldapsearch will return busy code first time and then success
          expect(@plugin).to receive(:run_command).with(%r{ldapsearch})
                                                  .and_return(ldap_busy_response, success_response_simpkvKey)

          result = @plugin.get(key)
          expect(result[:result]).to eq(stored_value)
          expect(result[:err_msg]).to be_nil
        end

        it 'fails when simpkvKey object missing simpkvJsonValue attribute' do
          # successful query result, but instead of simpkvJsonValue attribute
          # has simpkvValue attribute
          success_response_malformed_simpkvKey = {
            success: true,
            exitstatus: 0,
            stdout: <<~EOM,
              dn: #{key_dn}
              objectClass: simpkvEntry
              objectClass: top
              simpkvKey: #{base_key}
              simpkvValue: #{stored_value}
            EOM
          }

          expect(@plugin).to receive(:run_command).with(%r{ldapsearch})
                                                  .and_return(success_response_malformed_simpkvKey)

          result = @plugin.get(key)
          expect(result[:result]).to be_nil
          expect(result[:err_msg]).to match(%r{Key retrieval did not return key/value entry})
        end

        it 'returns failure when retries fail' do
          # ldapsearch will return busy code both times
          expect(@plugin).to receive(:run_command).with(%r{ldapsearch})
                                                  .and_return(ldap_busy_response, ldap_busy_response)

          result = @plugin.get(key)
          expect(result[:result]).to be_nil
          expect(result[:err_msg]).to eq(ldap_busy_response[:stderr])
        end

        it 'returns failure when other ldapsearch failure occurs' do
          expect(@plugin).to receive(:run_command).with(%r{ldapsearch})
                                                  .and_return(ldap_other_error_response)

          result = @plugin.get(key)
          expect(result[:result]).to be_nil
          expect(result[:err_msg]).to eq(ldap_other_error_response[:stderr])
        end
      end

      describe '#list' do
        let(:success_response_not_empty) do
          {
            success: true,
         exitstatus: 0,
         stdout: <<~EOM,
           dn: #{folder_dn}
           ou: #{base_folder}
           objectClass: top
           objectClass: organizationalUnit

           dn: #{key_dn}
           objectClass: simpkvEntry
           objectClass: top
           simpkvKey: #{base_key}
           simpkvJsonValue: #{stored_value}
          EOM
          }
        end

        it 'returns success when retries succeed' do
          # ldapsearch will return busy code first time and then success
          expect(@plugin).to receive(:run_command).with(%r{ldapsearch})
                                                  .and_return(ldap_busy_response, success_response_not_empty)

          result = @plugin.list(File.dirname(folder))
          expected_list = {
            keys: { base_key => stored_value },
            folders: [ base_folder ],
          }

          expect(result[:result]).to eq(expected_list)
          expect(result[:err_msg]).to be_nil
        end

        it 'returns failure when retries fail' do
          # ldapsearch will return busy code both times
          expect(@plugin).to receive(:run_command).with(%r{ldapsearch})
                                                  .and_return(ldap_busy_response, ldap_busy_response)

          result = @plugin.list(key)
          expect(result[:result]).to be_nil
          expect(result[:err_msg]).to eq(ldap_busy_response[:stderr])
        end

        it 'returns failure when other ldapsearch failure occurs' do
          expect(@plugin).to receive(:run_command).with(%r{ldapsearch})
                                                  .and_return(ldap_other_error_response)

          result = @plugin.list(key)
          expect(result[:result]).to be_nil
          expect(result[:err_msg]).to eq(ldap_other_error_response[:stderr])
        end
      end

      describe '#put' do
        let(:failed_ldap_result) do
          {
            success: false,
         exitstatus: 1,
         err_msg: 'Some interim ldap operation failed',
          }
        end

        let(:successful_ldap_result) do
          {
            success: true,
         exitstatus: 0,
          }
        end

        let(:failed_update_result) do
          {
            result: false,
         err_msg: 'Update failed',
          }
        end

        it 'returns failure when ensure_folder_path fails' do
          expect(@plugin).to receive(:ensure_folder_path)
            .with('instances/default/environments/production')
            .and_return(failed_ldap_result)

          result = @plugin.put(key, value)
          expect(result[:result]).to be false
          expect(result[:err_msg]).to eq(failed_ldap_result[:err_msg])
        end

        it "returns failure when ldap_add with 'already exists' error and update_value_if_changed fails" do
          expect(@plugin).to receive(:ensure_folder_path)
            .with('instances/default/environments/production')
            .and_return(successful_ldap_result)

          already_exists_result = {
            success: false,
            exitstatus: 68,
            err_msg: 'Already exists',
          }
          expect(@plugin).to receive(:ldap_add).and_return(already_exists_result)
          expect(@plugin).to receive(:update_value_if_changed).with(key, value)
                                                              .and_return(failed_update_result)

          result = @plugin.put(key, value)
          expect(result).to eq(failed_update_result)
        end

        it 'returns failure when ldap_add fails with other error' do
          expect(@plugin).to receive(:ensure_folder_path)
            .with('instances/default/environments/production')
            .and_return(successful_ldap_result)

          expect(@plugin).to receive(:ldap_add).and_return(failed_ldap_result)
          result = @plugin.put(key, value)
          expect(result[:result]).to be false
          expect(result[:err_msg]).to eq(failed_ldap_result[:err_msg])
        end
      end
    end
  end

  context 'internal methods' do
    before(:each) do
      @plugin = plugin_class.new('ldap/ldapi')
      options = @options.merge({ 'backend' => 'default' })

      # allow instead of expect because of set_base_ldap_commands test
      allow(Facter::Core::Execution).to receive(:which).with('ldapadd').and_return('/usr/bin/ldapadd')
      allow(Facter::Core::Execution).to receive(:which).with('ldapdelete').and_return('/usr/bin/ldapdelete')
      allow(Facter::Core::Execution).to receive(:which).with('ldapmodify').and_return('/usr/bin/ldapmodify')
      allow(Facter::Core::Execution).to receive(:which).with('ldapsearch').and_return('/usr/bin/ldapsearch')

      expect(@plugin).to receive(:verify_ldap_access)
      expect(@plugin).to receive(:ensure_instance_tree)
      @plugin.configure(options)
    end

    describe '#ensure_folder_path' do
      it 'returns success when no folders in existing_folders & all ldap_add' do
        @plugin.existing_folders.clear

        [
          'dn: ou=instances,ou=simpkv,o=puppet,dc=simp',
          'dn: ou=default,ou=instances,ou=simpkv,o=puppet,dc=simp',
          'dn: ou=environments,ou=default,ou=instances,ou=simpkv,o=puppet,dc=simp',
          'dn: ou=production,ou=environments,ou=default,ou=instances,ou=simpkv,o=puppet,dc=simp',
        ].each do |dn|
          expect(@plugin).to receive(:ldap_add).with(%r{#{dn}}, true)
                                               .and_return(success_response_simple)
        end

        expect(@plugin.ensure_folder_path(File.dirname(full_key_path)))
          .to eq(success_response_simple.merge({ err_msg: nil }))

        expected_folders = Set.new
        expected_folders.add('instances')
        expected_folders.add('instances/default')
        expected_folders.add('instances/default/environments')
        expected_folders.add('instances/default/environments/production')
        expect(@plugin.existing_folders).to eq(expected_folders)
      end

      it 'returns success when some folders in existing_folders & ldap_add succeeds for new folders' do
        @plugin.existing_folders.clear
        @plugin.existing_folders.add('instances')
        @plugin.existing_folders.add('instances/default')
        @plugin.existing_folders.add('instances/default/environments')
        dn = 'dn: ou=production,ou=environments,ou=default,ou=instances,ou=simpkv,o=puppet,dc=simp'

        expect(@plugin).to receive(:ldap_add).with(%r{#{dn}}, true)
                                             .and_return(success_response_simple)

        expect(@plugin.ensure_folder_path(File.dirname(full_key_path)))
          .to eq(success_response_simple.merge({ err_msg: nil }))
      end

      it 'returns failure if any ldap_add fails' do
        @plugin.existing_folders.clear
        @plugin.existing_folders.add('instances')
        @plugin.existing_folders.add('instances/default')

        dn1 = 'dn: ou=environments,ou=default,ou=instances,ou=simpkv,o=puppet,dc=simp'
        expect(@plugin).to receive(:ldap_add).with(%r{#{dn1}}, true)
                                             .and_return(success_response_simple)

        dn2 = 'dn: ou=production,ou=environments,ou=default,ou=instances,ou=simpkv,o=puppet,dc=simp'
        failed_add_response = {
          success: false,
          exitstatus: 1,
          err_msg: 'ldapadd failed',

        }

        expect(@plugin).to receive(:ldap_add).with(%r{#{dn2}}, true)
                                             .and_return(failed_add_response)

        expect(@plugin.ensure_folder_path(File.dirname(full_key_path)))
          .to eq(failed_add_response)

        failed_folder = 'instances/default/environments/production'
        expect(@plugin.existing_folders.include?(failed_folder)).to be false
      end
    end

    describe '#ldap_add' do
      let(:ldap_already_exists_response) do
        {
          success: false,
        exitstatus: 68,
        stdout: '',
        stderr: 'ldapadd failed:\nDN already exists',
        }
      end

      context 'ignore_already_exists=false (default)' do
        it 'returns failure when ldapadd fails because DN already exists' do
          expect(@plugin).to receive(:run_command).with(%r{ldapadd})
                                                  .and_return(ldap_already_exists_response)

          result = @plugin.ldap_add('some ldif')
          expect(result[:success]).to be false
          expect(result[:exitstatus]).to eq(ldap_already_exists_response[:exitstatus])
          expect(result[:err_msg]).to eq(ldap_already_exists_response[:stderr])
        end

        it 'returns success when retries succeed' do
          # ldapadd will return busy code first time and then success
          expect(@plugin).to receive(:run_command).with(%r{ldapadd})
                                                  .and_return(ldap_busy_response, success_response_simple)

          result = @plugin.ldap_add('some ldif')
          expect(result[:success]).to be true
          expect(result[:exitstatus]).to eq 0
          expect(result[:err_msg]).to be_nil
        end

        it 'returns failure when retries fail' do
          # ldapadd will return busy code both times
          expect(@plugin).to receive(:run_command).with(%r{ldapadd})
                                                  .and_return(ldap_busy_response, ldap_busy_response)

          result = @plugin.ldap_add('some ldif')
          expect(result[:success]).to be false
          expect(result[:exitstatus]).to eq(ldap_busy_response[:exitstatus])
          expect(result[:err_msg]).to eq(ldap_busy_response[:stderr])
        end

        it 'returns failure when other ldapadd failure occurs' do
          expect(@plugin).to receive(:run_command).with(%r{ldapadd})
                                                  .and_return(ldap_other_error_response)

          result = @plugin.ldap_add('some ldif')
          expect(result[:success]).to be false
          expect(result[:exitstatus]).to eq(ldap_other_error_response[:exitstatus])
          expect(result[:err_msg]).to eq(ldap_other_error_response[:stderr])
        end
      end

      context 'ignore_already_exists=true' do
        it 'returns success when ldapadd fails because DN already exists' do
          expect(@plugin).to receive(:run_command).with(%r{ldapadd})
                                                  .and_return(ldap_already_exists_response)

          result = @plugin.ldap_add('some ldif', true)
          expect(result[:success]).to be true
          expect(result[:exitstatus]).to eq 0
          expect(result[:err_msg]).to be_nil
        end
      end
    end

    describe '#ldap_modify' do
      it 'returns success when retries succeed' do
        # ldapmodify will return busy code first time and then success
        expect(@plugin).to receive(:run_command).with(%r{ldapmodify})
                                                .and_return(ldap_busy_response, success_response_simple)

        result = @plugin.ldap_modify('some LDIF content')
        expect(result[:success]).to be true
        expect(result[:exitstatus]).to eq 0
        expect(result[:err_msg]).to be_nil
      end

      it 'returns failure when retries fail' do
        # ldapmodify will return busy code both times
        expect(@plugin).to receive(:run_command).with(%r{ldapmodify})
                                                .and_return(ldap_busy_response, ldap_busy_response)

        result = @plugin.ldap_modify('some LDIF content')
        expect(result[:success]).to be false
        expect(result[:exitstatus]).to eq(ldap_busy_response[:exitstatus])
        expect(result[:err_msg]).to eq(ldap_busy_response[:stderr])
      end

      it 'returns failure when DN no longer exists' do
        expect(@plugin).to receive(:run_command).with(%r{ldapmodify})
                                                .and_return(ldap_no_such_object_response)

        result = @plugin.ldap_modify('some LDIF content')
        expect(result[:success]).to be false
        expect(result[:exitstatus]).to eq(ldap_no_such_object_response[:exitstatus])
        expect(result[:err_msg]).to eq(ldap_no_such_object_response[:stderr])
      end

      it 'returns failure when other ldapmodify failure occurs' do
        expect(@plugin).to receive(:run_command).with(%r{ldapmodify})
                                                .and_return(ldap_other_error_response)

        result = @plugin.ldap_modify('some LDIF content')
        expect(result[:success]).to be false
        expect(result[:exitstatus]).to eq(ldap_other_error_response[:exitstatus])
        expect(result[:err_msg]).to eq(ldap_other_error_response[:stderr])
      end
    end

    describe '#path_to_dn' do
      context 'leaf_is_key=true (default)' do
        it 'returns DN for simpkvKey node when path has no folders' do
          actual = @plugin.path_to_dn('key')
          expect(actual).to eq('simpkvKey=key,ou=simpkv,o=puppet,dc=simp')
        end

        it 'returns DN for simpkvKey node when path has folders' do
          actual = @plugin.path_to_dn('environments/dev/key')
          expect(actual).to eq('simpkvKey=key,ou=dev,ou=environments,ou=simpkv,o=puppet,dc=simp')
        end
      end

      context 'leaf_is_folder=false' do
        it 'returns DN for ou node when path has no folders' do
          actual = @plugin.path_to_dn('folder', false)
          expect(actual).to eq('ou=folder,ou=simpkv,o=puppet,dc=simp')
        end

        it 'returns DN for ou node when path has folders' do
          actual = @plugin.path_to_dn('environments/dev/folder', false)
          expect(actual).to eq('ou=folder,ou=dev,ou=environments,ou=simpkv,o=puppet,dc=simp')
        end
      end
    end

    describe '#parse_config' do
      context 'valid configuration' do
        it 'defaults base_dn to ou=simpkv,o=puppet,dc=simp' do
          config = @options['backends']['default']
          opts = @plugin.parse_config(config)
          expect(opts[:base_dn]).to eq('ou=simpkv,o=puppet,dc=simp')
        end

        it 'defaults admin_dn to cn=Directory_Manager' do
          config = @options['backends']['unencrypted']
          opts = @plugin.parse_config(config)
          expect(opts[:base_opts]).to match(%r{-D "cn=Directory_Manager"})
        end

        it 'defaults retries to 1' do
          config = @options['backends']['default']
          opts = @plugin.parse_config(config)
          expect(opts[:retries]).to eq(1)
        end

        it 'transforms valid ldapi config without admin_dn and admin_pw_file' do
          config = @options['backends']['default']
          opts = @plugin.parse_config(config)
          expect(opts[:cmd_env]).to eq('')
          expect(opts[:base_opts]).to eq("-Y EXTERNAL -H #{config['ldap_uri']}")
        end

        it 'transforms valid ldapi config with admin_dn and admin_pw_file' do
          config = @options['backends']['default'].merge({
                                                           'admin_dn' => 'cn=My_Directory_Manager',
            'admin_pw_file' => @admin_pw_file,
                                                         })
          opts = @plugin.parse_config(config)
          expect(opts[:cmd_env]).to eq('')
          exp_base = [
            '-x',
            %(-D "#{config['admin_dn']}"),
            "-y #{config['admin_pw_file']}",
            "-H #{config['ldap_uri']}",
          ].join(' ')
          expect(opts[:base_opts]).to eq(exp_base)
        end

        it 'transforms valid unencrypted ldap config' do
          config = @options['backends']['unencrypted']
          opts = @plugin.parse_config(config)
          expect(opts[:cmd_env]).to eq('')
          exp_base = [
            '-x',
            '-D "cn=Directory_Manager"',
            "-y #{config['admin_pw_file']}",
            "-H #{config['ldap_uri']}",
          ].join(' ')
          expect(opts[:base_opts]).to eq(exp_base)
        end

        it 'transforms valid unencrypted ldap config with enable_tls=false' do
          config = @options['backends']['unencrypted'].merge({ 'enable_tls' => false })
          opts = @plugin.parse_config(config)
          expect(opts[:cmd_env]).to eq('')

          exp_base = [
            '-x',
            '-D "cn=Directory_Manager"',
            "-y #{config['admin_pw_file']}",
            "-H #{config['ldap_uri']}",
          ].join(' ')
          expect(opts[:base_opts]).to eq(exp_base)
        end

        it 'transforms valid encrypted ldap (StartTLS) config' do
          config = @options['backends']['starttls']
          opts = @plugin.parse_config(config)
          exp_env = [
            "LDAPTLS_CERT=#{config['tls_cert']}",
            "LDAPTLS_KEY=#{config['tls_key']}",
            "LDAPTLS_CACERT=#{config['tls_cacert']}",
          ].join(' ')
          expect(opts[:cmd_env]).to eq(exp_env)

          exp_base = [
            '-ZZ',
            '-x',
            '-D "cn=Directory_Manager"',
            "-y #{config['admin_pw_file']}",
            "-H #{config['ldap_uri']}",
          ].join(' ')
          expect(opts[:base_opts]).to eq(exp_base)
        end

        it 'transforms valid encrypted ldaps config' do
          config = @options['backends']['tls']
          opts = @plugin.parse_config(config)
          exp_env = [
            "LDAPTLS_CERT=#{config['tls_cert']}",
            "LDAPTLS_KEY=#{config['tls_key']}",
            "LDAPTLS_CACERT=#{config['tls_cacert']}",
          ].join(' ')
          expect(opts[:cmd_env]).to eq(exp_env)

          exp_base = [
            '',
            '-x',
            '-D "cn=Directory_Manager"',
            "-y #{config['admin_pw_file']}",
            "-H #{config['ldap_uri']}",
          ].join(' ')
          expect(opts[:base_opts]).to eq(exp_base)
        end
      end

      context 'invalid configuration' do
        it 'fails when ldap_uri is missing' do
          config = {}
          expect { @plugin.parse_config(config) }
            .to raise_error(%r{Plugin missing 'ldap_uri' configuration})
        end

        it 'fails if ldap_uri is malformed' do
          config = { 'ldap_uri' => 'ldaps:/too.few.slashes.com' }
          expect { @plugin.parse_config(config) }
            .to raise_error(%r{Invalid 'ldap_uri' configuration})
        end

        it 'fails if admin_pw_file missing and not ldapi' do
          config = Marshal.load(Marshal.dump(@options['backends']['unencrypted']))
          config.delete('admin_pw_file')
          expect { @plugin.parse_config(config) }
            .to raise_error(%r{Plugin missing 'admin_pw_file' configuration})
        end

        it 'fails if admin_pw_file does not exist' do
          config = @options['backends']['default'].merge({ 'admin_pw_file' => '/does/not/exist' })
          expect { @plugin.parse_config(config) }
            .to raise_error(%r{Configured 'admin_pw_file' /does/not/exist does not exist})
        end

        it 'fails if TLS configuration incomplete' do
          config = Marshal.load(Marshal.dump(@options['backends']['tls']))
          config.delete('tls_cacert')
          expect { @plugin.parse_config(config) }
            .to raise_error(%r{TLS configuration incomplete})
        end
      end
    end

    # all the weird error cases tested below could only happen if someone manually
    # inserted entries into the LDIF tree
    describe '#parse_list_ldif' do
      it 'skips a malformed organizationalUnit' do
        # don't know how this could ever happen...totally artifical example
        ldif = <<~EOM
          dn: #{folder_dn}
          ou: #{base_folder}
          objectClass: top
          objectClass: organizationalUnit

          dn: custom=something,#{production_dn}
          custom: something
          objectClass: top
          objectClass: organizationalUnit
          objectClass: custom

          dn: #{key_dn}
          objectClass: simpkvEntry
          objectClass: top
          simpkvKey: #{base_key}
          simpkvJsonValue: #{stored_value}
        EOM

        result = @plugin.parse_list_ldif(ldif)
        expected = {
          keys: { base_key => stored_value },
          folders: [ base_folder ],
        }
        expect(result).to eq(expected)
      end

      it 'skips simpkvEntry missing the simpkvJsonValue attribute' do
        ldif = <<~EOM
          dn: #{folder_dn}
          ou: #{base_folder}
          objectClass: top
          objectClass: organizationalUnit

          dn: #{key_dn}
          objectClass: simpkvEntry
          objectClass: top
          simpkvKey: #{base_key}
        EOM

        result = @plugin.parse_list_ldif(ldif)
        expected = { keys: {}, folders: [ base_folder ] }
        expect(result).to eq(expected)
      end

      it 'skips simpkvEntry missing the simpkvKey attribute' do
        ldif = <<~EOM
          dn: #{folder_dn}
          ou: #{base_folder}
          objectClass: top
          objectClass: organizationalUnit

          dn: #{key_dn}
          objectClass: simpkvEntry
          objectClass: top
          simpkvJsonValue: #{stored_value}
        EOM

        result = @plugin.parse_list_ldif(ldif)
        expected = { keys: {}, folders: [ base_folder ] }
        expect(result).to eq(expected)
      end

      it 'skips any object that is not a simpkvEntry or organizationalUnit' do
        ldif = <<~EOM
          dn: #{folder_dn}
          ou: #{base_folder}
          objectClass: top
          objectClass: organizationalUnit

          dn: custom=something,#{production_dn}
          custom: something
          objectClass: top
          objectClass: custom

          dn: #{key_dn}
          objectClass: simpkvEntry
          objectClass: top
          simpkvKey: #{base_key}
          simpkvJsonValue: #{stored_value}
        EOM

        result = @plugin.parse_list_ldif(ldif)
        expected = {
          keys: { base_key => stored_value },
          folders: [ base_folder ],
        }
        expect(result).to eq(expected)
      end
    end

    describe '#run_command' do
      it 'returns success results when command succeeds' do
        command = "ls #{__FILE__}"
        result = @plugin.run_command(command)
        expect(result[:success]).to eq true
        expect(result[:exitstatus]).to eq 0
        expect(result[:stdout]).to match __FILE__.to_s
        expect(result[:stderr]).to eq ''
      end

      it 'returns failed results when command fails' do
        command = 'ls /some/missing/path1'
        result = @plugin.run_command(command)
        expect(result[:success]).to eq false
        expect(result[:exitstatus]).to eq 2
        expect(result[:stdout]).to eq ''
        expect(result[:stderr]).to match(%r{No such file or directory})
      end
    end

    describe '#set_base_ldap_commands' do
      it 'fails when ldap* commands cannot be found' do
        expect(Facter::Core::Execution).to receive(:which).with('ldapadd').and_return(nil)
        expect { @plugin.set_base_ldap_commands('', 'some base opts') }
          .to raise_error(%r{Missing required ldapadd command})
      end
    end

    describe '#tls_enabled?' do
      it 'returns false when using ldapi' do
        config = @options['backends']['default']
        expect(@plugin.tls_enabled?(config)).to be false
      end

      it 'returns true when using ldaps' do
        config = @options['backends']['tls']
        expect(@plugin.tls_enabled?(config)).to be true
      end

      it 'returns ignores enable_tls when using ldaps' do
        config = @options['backends']['tls'].merge({ 'enable_tls' => false })
        expect(@plugin.tls_enabled?(config)).to be true
      end

      it 'returns true when using ldap and enable_tls=true' do
        config = @options['backends']['starttls']
        expect(@plugin.tls_enabled?(config)).to be true
      end

      it 'returns false when using ldap and enable_tls=false' do
        config = Marshal.load(Marshal.dump(@options['backends']['starttls']))
        config['enable_tls'] = false
        expect(@plugin.tls_enabled?(config)).to be false
      end

      it 'returns false when using ldap and enable_tls is absent' do
        config = @options['backends']['unencrypted']
        expect(@plugin.tls_enabled?(config)).to be false
      end
    end

    describe '#update_value_if_changed' do
      let(:new_stored_value) { '{"value":"new value","metadata":{}}' }

      it 'reports failure when get() for the current value fails' do
        failed_get_result = { :result => nil, 'err_msg' => 'No such object' }
        expect(@plugin).to receive(:get).with(key).and_return(failed_get_result)

        result = @plugin.update_value_if_changed(key, new_stored_value)
        expect(result[:result]).to be false
        expect(result[:err_msg]).to match(%r{Failed to retrieve current value for comparison})
      end

      it 'reports failure when ldap_modify() fails' do
        success_get_result = { :result => stored_value, 'err_msg' => nil }
        expect(@plugin).to receive(:get).with(key).and_return(success_get_result)
        expect(@plugin).to receive(:ldap_modify).with(%r{#{new_stored_value}})
                                                .and_return(ldap_other_error_response)

        result = @plugin.update_value_if_changed(key, new_stored_value)
        expect(result[:result]).to be false
        expect(result[:err_msg]).to eq(ldap_other_error_response[:err_msg])
      end
    end

    # easiest way to test verify_ldap_access is via configure
    describe '#verify_ldap_access' do
      before(:each) do
        @plugin2 = plugin_class.new('ldap/ldapi')
        @options2 = @options.merge({ 'backend' => 'default' })
        expect(Facter::Core::Execution).to receive(:which).with('ldapadd').and_return('/usr/bin/ldapadd')
        expect(Facter::Core::Execution).to receive(:which).with('ldapdelete').and_return('/usr/bin/ldapdelete')
        expect(Facter::Core::Execution).to receive(:which).with('ldapmodify').and_return('/usr/bin/ldapmodify')
        expect(Facter::Core::Execution).to receive(:which).with('ldapsearch').and_return('/usr/bin/ldapsearch')
      end

      it 'succeeds when retries succeed' do
        expect(@plugin2).to receive(:run_command).with(%r{ldapsearch})
                                                 .and_return(ldap_busy_response, success_response_simple)
        expect(@plugin2).to receive(:ensure_instance_tree)

        expect { @plugin2.configure(@options2) }.not_to raise_error
      end

      it 'fails when retries fail' do
        expect(@plugin2).to receive(:run_command).with(%r{ldapsearch})
                                                 .and_return(ldap_busy_response, ldap_busy_response)

        expect { @plugin2.configure(@options2) }
          .to raise_error(%r{Plugin could not access ou=simpkv,o=puppet,dc=simp})
      end
    end
  end
end
