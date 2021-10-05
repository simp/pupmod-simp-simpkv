require 'acceptance/helpers/utils'
include Acceptance::Helpers::Utils

# Validate file-plugin-managed keys on the local filesystem
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
# NOTE: Uses local filesystem commands, since the file plugin has to be on the
#       same host as the file keystore.
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
#   - Must be same host as file keystore
#
# @return Whether validation of keys succeeded
#
# @raise RuntimeError if the appropriate backend for each app_id within key_info
#   cannot be found in backend_hiera
#
def validate_file_entries(key_info, keys_should_exist, backend_hiera, host)
  errors = []
  key_info.each do |app_id, key_struct|
    config = backend_config_for_app_id(app_id, 'file', backend_hiera)
    key_struct.each do |key_type, keys|
      keys.each do |key, key_data|
        result = {}
        if keys_should_exist
          result = validate_file_key_entry_present(key, key_type, key_data, config, host)
        else
          result = validate_file_key_entry_absent(key, key_type, config, host)
        end

        unless result[:success]
          errors << result[:err_msg]
        end
      end
    end
  end

  if errors.size == 0
    true
  else
    warn('Validation Failures:')
    errors.each do |error|
      warn("  #{error}")
    end

    false
  end
end

# Validate a that file-plugin-managed key exists on the local filesystem and
# has the correct stored data
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
#   - Must be same host as file file keystore
#
# @return results Hash
#   * :success - whether the validation succeeded
#   * :err_msg - error message upon failure or nil otherwise
#
def validate_file_key_entry_present(key, key_type, key_data, config, host)
  result = { :success => true }

  key_path = filesystem_key_path(key, key_type, config)
  cmd_result = on(host, "cat #{key_path}", :accept_all_exit_codes => true)
  if cmd_result.exit_code == 0
    expected_key_string = key_data_string(key_data)
    if cmd_result.stdout.strip != expected_key_string
      result = {
        :success => false,
        :err_msg => [
          "Data for #{key} did not match expected:",
          "  Expected: #{expected_key_string}",
          "  Actual:   #{result.stdout}"
        ].join("\n")
      }
    end
  else
    result = {
      :success => false,
      :err_msg => "Validation of #{key} presence failed: Could not find #{key_path}"
    }
  end

  result
end

# Validate a that file-plugin-managed key does not exists on the local filesystem
#
# @param key Key name
#
# @param key_type 'env' or 'global' for a key tied to the Puppet-environment
#   or a global key, respectively
#
# @param config Backend configuration
#
# @param host Host object on which the validator will execute commands
#   - Must be same host as file file keystore
#
# @return results Hash
#   * :success - whether the validation succeeded
#   * :err_msg - error message upon failure or nil otherwise
#
def validate_file_key_entry_absent(key, key_type, config, host)
  result = { :success => true }

  key_path = filesystem_key_path(key, key_type, config)
  cmd_result = on(host, "ls -l #{key_path}", :accept_all_exit_codes => true)
  if result.exit_code == 0
    result = {
      :success => false,
      :err_msg => "Validation of #{key} absence failed: Found #{key_path}"
    }
  end

  result
end

def filesystem_key_path(key, key_type, config)
  root_path = config.key?('root_path') ? config['root_path'] : '/var/simp/simpkv/file/default'
  if key_type == 'global'
    File.join(root_path, 'globals', key)
  else
    File.join(root_path, 'environments', 'production', key)
  end
end
