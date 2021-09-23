require 'acceptance/helpers/utils'
include Acceptance::Helpers::Utils

# Validate file-plugin-managed keys on the local filesystem
#
# - Conforms to the API specified in 'a simpkv plugin test' shared_examples
# - Uses local filesystem commands, since the file plugin has to be on the
#   same host as the file keystore
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
def validate_file_entries(key_info, keys_should_exist, backend_hiera, host)
  if keys_should_exist
    validate_file_entries_present(key_info, backend_hiera, host)
  else
    validate_file_entries_absent(key_info, backend_hiera, host)
  end
end

# Validate that file-plugin-managed keys exist on the local filesystem
#
# For each key specification,
# - Selects the backend whose name matches its 'app_id'  or 'default', when
#   no match is found
# - Checks for the existence of the appropriate file for the backend
# - Verifies the file content, when the file exists
#
# @param key_info Hash of key information whose format corresponds to the
#   Simpkv_test::KeyInfo type alias
#
# @param backend_hiera Hash of backend configuration ('simpkv::options' Hash)
#
# @param host Host object on which the validator will execute commands
#   - Must be same host as file file keystore
#
# @return Whether validation of keys succeeded
#
def validate_file_entries_present(key_info, backend_hiera, host)
  errors = []
  key_info.each do |app_id, key_struct|
    root_path = file_root_path_for_app_id(app_id, backend_hiera)
    key_struct.each do |key_type, keys|
      key_root_path = (key_type == 'global') ? "#{root_path}/globals" : "#{root_path}/environments/production"
      keys.each do |key, key_data|
        key_path = "#{key_root_path}/#{key}"
        expected_key_string = key_data_string(key_data)
        result = on(host, "cat #{key_path}", :accept_all_exit_codes => true)
        if result.exit_code == 0
          if result.stdout.strip != expected_key_string
            errors << [
              "Contents of #{key_path} did not match expected:",
              "  Expected: #{expected_key_string}",
              "  Actual:   #{result.stdout}"
            ].join("\n")
          end
        else
          errors << "Validation of #{key_path} presence and data failed: #{result.stderr}"
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

# Validate that file-plugin-managed keys do not exist on the local filesystem
#
# For each key specification,
# - Selects the backend whose name matches its 'app_id'  or 'default', when
#   no match is found
# - Checks for the existence of the appropriate file for the backend
#
# @param key_info Hash of key information whose format corresponds to the
#   Simpkv_test::KeyInfo type alias
#
# @param backend_hiera Hash of backend configuration ('simpkv::options' Hash)
#
# @param host Host object on which the validator will execute commands
#   - Must be same host as file file keystore
#
# @return Whether validation of keys succeeded
#
def validate_file_entries_absent(key_info, backend_hiera, host)
  errors = []
  key_info.each do |app_id, key_struct|
    root_path = file_root_path_for_app_id(app_id, backend_hiera)
    key_struct.each do |key_type, keys|
      key_root_path = (key_type == 'global') ? "#{root_path}/globals" : "#{root_path}/environments/production"
      keys.each do |key, key_data|
        key_path = "#{key_root_path}/#{key}"
        result = on(host, "ls -l #{key_path}", :accept_all_exit_codes => true)
        if result.exit_code == 0
          errors << "Validation of #{key_path} absence failed: #{result.stdout}"
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

# @return Root path for the file backend that corresponds to the app_id
#
# @param app_id The app_id for a key or '', if none specified
# @param backend_hiera Hash of backend configuration ('simpkv::options' Hash)
#
def file_root_path_for_app_id(app_id, backend_hiera)
  root_path = ''
  if backend_hiera['simpkv::options']['backends'].keys.include?(app_id)
    root_path = backend_hiera["simpkv::backend::#{app_id}"]['root_path']
  elsif backend_hiera['simpkv::options']['backends'].keys.include?('default')
    root_path = backend_hiera['simpkv::backend::default']['root_path']
  end

  root_path
end
