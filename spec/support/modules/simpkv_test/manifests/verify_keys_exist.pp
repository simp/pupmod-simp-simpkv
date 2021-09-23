# @summary Check for the existence of keys using simpkv::exists
#
# @param valid_keyname_info
#   Info specifying names of keys that are expected to be present in the
#   keystore
#
# @param invalid_keyname_info
#   Info specifying names of keys that are not expected to be present in
#   the keystore
#
class simpkv_test::verify_keys_exist (
  Simpkv_test::NameInfo $valid_keyname_info,
  Simpkv_test::NameInfo $invalid_keyname_info
) {

  $_keys_to_check = {
    true  => $valid_keyname_info,
    false => $invalid_keyname_info
  }

  $_keys_to_check.each |$valid, $key_info| {
    $key_info.each |$app_id, $key_struct| {
      $key_struct.each |$key_type, $keynames| {
        $_simpkv_options = simpkv_test::simpkv_options($app_id, $key_type)

        $keynames.each |$key| {
          $_unique_id = "${app_id}_${key_type}_${key}"
          case simpkv_test::code_source($_unique_id) {
            'class': {
              $_message = "simpkv::exists('${key}', ${_simpkv_options})"
              info("Calling ${_message}")
              $_key_exists = simpkv::exists($key, $_simpkv_options)
              simpkv_test::assert_equal( $_key_exists, $valid, $_message)
            }
            'define': {
              simpkv_test::defines::verify_name_exists{ $_unique_id:
                key            => $key,
                simpkv_options => $_simpkv_options,
                valid          => $valid
              }
            }
            'puppet_function': {
              simpkv_test::puppet_functions::verify_name_exists($key,
                $_simpkv_options, $valid)
            }
          }
        }
      }
    }
  }
}
