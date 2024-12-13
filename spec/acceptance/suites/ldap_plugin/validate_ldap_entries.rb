require 'acceptance/helpers/ldap_utils'
require 'acceptance/helpers/utils'
include Acceptance::Helpers::LdapUtils
include Acceptance::Helpers::Utils

# Validate ldap-plugin-managed keys on the LDAP server
#
# For each key specification,
# - Selects the backend whose name matches its 'app_id'  or 'default', when
#   no match is found
# - Checks for the existence of the key in the appropriate location in the
#   backend
# - When the key is supposed to exist and does exist, verifies the stored data
#
# Conforms to the API specified in 'a simpkv plugin test' shared_examples
#
# @param key_info Hash of key information whose format corresponds to the
#   Simpkv_test::KeyInfo type alias
#
# @param keys_should_exist Whether keys should exist
#   - true = verify keys are present with correct stored data
#   - false = verify keys are absent
#
# @param backend_hiera Hash of backend configuration ('simpkv::options' Hash)
#
# @param host Host object on which the validator will execute commands
#   - LDAP keystore not assumed to be on
#
# @return Whether validation of keys succeeded
#
# @raise RuntimeError if the appropriate backend for each app_id within key_info
#   cannot be found in backend_hiera
#
def validate_ldap_entries(key_info, keys_should_exist, backend_hiera, host)
  # TODO: Make the iteration through keys and backend config selection part
  #      of the test infrastructure instead of having this code replicated
  #      in each plugin-provided validator
  #
  errors = []
  key_info.each do |app_id, key_struct|
    config = backend_config_for_app_id(app_id, 'ldap', backend_hiera)
    key_struct.each do |key_type, keys|
      keys.each do |key, key_data|
        result = if keys_should_exist
                   validate_ldap_key_entry_present(key, key_type, key_data, config, host)
                 else
                   validate_ldap_key_entry_absent(key, key_type, config, host)
                 end

        unless result[:success]
          errors << result[:err_msg]
        end
      end
    end
  end

  if errors.empty?
    true
  else
    warn('Validation Failures:')
    errors.each do |error|
      warn("  #{error}")
    end

    false
  end
end

# Validate that a ldap-plugin-managed key exists on the LDAP server and has
# the correct stored data
#
# @param key Key name
#
# @param key_type 'env' or 'global' for a key tied to the Puppet-environment
#   or a global key, respectively
#
# @param key_data Hash of key data whose format corresponds to the
#   Simpkv_test::KeyData type alias
#
# @param config Backend configuration
#
# @param host Host object on which the validator will execute commands
#
# @return results Hash
#   * :success - whether the validation succeeded
#   * :err_msg - error message upon failure or nil otherwise
#
def validate_ldap_key_entry_present(key, key_type, key_data, config, host)
  result = { success: true }

  full_path = ldap_key_path(key, key_type, config)
  dn = build_key_dn(full_path, config['base_dn'])
  cmd = build_ldapsearch_cmd(dn, config, false)
  cmd_result = on(host, cmd, accept_all_exit_codes: true)
  if cmd_result.stdout.match(%r{^dn: .*#{dn}}).nil?
    result = {
      success: false,
      err_msg: "Validation of #{key} presence failed: Could not find #{dn}"
    }
  else
    expected_key_string = key_data_string(key_data)
    if cmd_result.stdout.match(%r{simpkvJsonValue: #{Regexp.escape(expected_key_string)}}).nil?
      result = {
        success: false,
        err_msg: [
          "Data for #{key} did not match expected:",
          "  Expected: simpkvJsonValue: #{expected_key_string}",
          "  Actual:   #{result.stdout}",
        ].join("\n")
      }
    end
  end

  result
end

# Validate that a ldap-plugin-managed key does not exist on the LDAP server
#
# @param key Key name
#
# @param key_type 'env' or 'global' for a key tied to the Puppet-environment
#   or a global key, respectively
#
# @param config Backend configuration
#
# @param host Host object on which the validator will execute commands
#
# @return results Hash
#   * :success - whether the validation succeeded
#   * :err_msg - error message upon failure or nil otherwise
#
def validate_ldap_key_entry_absent(key, key_type, config, host)
  result = { success: true }

  full_path = ldap_key_path(key, key_type, config)
  dn = build_key_dn(full_path, config['base_dn'])
  cmd = build_ldapsearch_cmd(dn, config, true)
  cmd_result = on(host, cmd, accept_all_exit_codes: true)
  unless cmd_result.exit_code == 32 # No such object
    result = {
      success: false,
      err_msg: "Validation of #{key} absence failed: Found #{dn}:\n#{result.stdout}"
    }
  end

  result
end

# @return keypath for the key
def ldap_key_path(key, key_type, config)
  plugin_instance_path = File.join('instances', config['id'])
  if key_type == 'global'
    File.join(plugin_instance_path, 'globals', key)
  else
    File.join(plugin_instance_path, 'environments', 'production', key)
  end
end

# @return ldapsearch command to list or check the existence of a DN
#
# @param dn DN to search for
# @param config LDAP backend config
# @param existence_only whether to just check for existence of the DN or
#   query for a listing of the DN
#
def build_ldapsearch_cmd(dn, config, existence_only)
  [
    build_ldap_command('ldapsearch', config),
    '-s base',
    "-b #{dn}",

    # TODO: switch to ldif_wrap when we drop support for EL7
    # - EL7 only supports ldif-wrap
    # - EL8 says it supports ldif_wrap (--help and man page), but actually
    #   accepts ldif-wrap or ldif_wrap
    '-o "ldif-wrap=no"',
    '-LLL',
    existence_only ? '1.1' : '',
  ].join(' ')
end
