require 'acceptance/helpers/utils'
require_relative '../default/validate_file_entries'
require_relative '../ldap_plugin/validate_ldap_entries'

include Acceptance::Helpers::Utils

# Validate keys managed by file and ldap plugins on filesystems and LDAP servers,
# respectively
#
# For each key specification,
# - Selects the backend whose name matches its 'app_id'  or 'default', when
#   no match is found
# - Checks for the existence of the key in the appropriate location in the
#   backend
# - When the key is supposed to exist and does exist, verifies the stored
#   content
#
# Conforms to the API specified in 'a simpkv plugin test' shared_examples
#
# NOTE: Uses local filesystem commands for keys managed by the file plugin,
#       since the file plugin has to be on the same host as the file keystore.
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
def validate_multiple_plugin_entries(key_info, keys_should_exist, backend_hiera, _host)
  errors = []
  key_info.each do |app_id, key_struct|
    config = backend_config_for_app_id(app_id, nil, backend_hiera)
    unless (config['type'] == 'file') || (config['type'] == 'ldap')
      raise("Unsupported backend type '#{config['type']}' found in backend hiera:\n#{backend_hiera}")
    end

    key_struct.each_value do |keys|
      keys.each do |_key, _key_data|
        exp = if keys_should_exist
                "validate_#{config['type']}_key_entry_present(key, key_type, key_data, config, host)"
              else
                "validate_#{config['type']}_key_entry_absent(key, key_type, config, host)"
              end
        result = eval(exp)

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
