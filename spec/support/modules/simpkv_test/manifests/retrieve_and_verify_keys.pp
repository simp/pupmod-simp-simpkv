# @summary Retrieve keys with simpkv::get and verifies the results
#
# @param valid_key_info
#   Info specifying keys that are expected to be present in the
#   keystore and their stored data
#
# @param invalid_key_info
#   Info specifying keys that are not expected to be present in the
#   keystore
#
class simpkv_test::retrieve_and_verify_keys (
  Simpkv_test::KeyInfo $valid_key_info,
  Simpkv_test::KeyInfo $invalid_key_info
) {

  $valid_key_info.each |$app_id, $key_struct| {
    $key_struct.each |$key_type, $keys| {
      $_simpkv_options = simpkv_test::simpkv_options($app_id, $key_type)

      $keys.each |$key, $key_data| {
        $_expected_value = simpkv_test::key_value($key_data)
        if $_expected_value =~ Undef {
          warning("Skipping '${app_id}' '${key_type}' key '${key}': Value not found in << ${key_data} >>")
          next
        }

        $_binary = ($_expected_value =~ Binary)
        $_expected_metadata = $key_data['metadata']

        $_unique_id = "${app_id}_${key_type}_${key}"
        case simpkv_test::code_source($_unique_id) {
          'class': {
            $_message = "simpkv::get('${key}', ${_simpkv_options})"
            info("Calling ${_message}")
            $_result = simpkv::get($key, $_simpkv_options)
            simpkv_test::verify_key_data($_result, $_expected_value,
              $_expected_metadata, $_binary, $_message)
          }
          'define': {
            simpkv_test::defines::retrieve_and_verify_key { $_unique_id:
              key               => $key,
              expected_value    => $_expected_value,
              expected_metadata => $_expected_metadata,
              simpkv_options    => $_simpkv_options,
              binary            => $_binary
            }
          }
          'puppet_function': {
            simpkv_test::puppet_functions::retrieve_and_verify_key($key,
              $_expected_value, $_expected_metadata, $_simpkv_options, $_binary)
          }
        }
      }
    }
  }

  $invalid_key_info.each |$app_id, $key_struct| {
    $key_struct.each |$key_type, $keys| {
      # Enable 'softfail', so failure returns Undef instead of failing catalog
      # compilation
      $_simpkv_options = simpkv_test::simpkv_options($app_id, $key_type,
        { 'softfail' => true })

      $keys.each |$key, $key_data| {
        $_expected_value = undef
        $_expected_metadata = undef
        $_binary = false          # value doesn't matter

        $_unique_id = "${app_id}_${key_type}_${key}"
        case simpkv_test::code_source($_unique_id) {
          'class': {
            $_message = "simpkv::get('${key}', ${_simpkv_options})"
            info("Calling ${_message}")
            $_result = simpkv::get($key, $_simpkv_options)
            simpkv_test::verify_key_data($_result, $_expected_value,
              $_expected_metadata, $_binary, $_message)
          }
          'define': {
            simpkv_test::defines::retrieve_and_verify_key { $_unique_id:
              key               => $key,
              expected_value    => $_expected_value,
              expected_metadata => $_expected_metadata,
              simpkv_options    => $_simpkv_options,
              binary            => $_binary
            }
          }
          'puppet_function': {
            simpkv_test::puppet_functions::retrieve_and_verify_key($key,
              $_expected_value, $_expected_metadata, $_simpkv_options, $_binary)
          }
        }
      }
    }
  }
}
