# @summary Store keys using simpkv::put
#
# @param key_info
#   Info specifying the key names and data to be stored
#
class simpkv_test::store_keys (
  Simpkv_test::KeyInfo $key_info
) {

  $key_info.each |$app_id, $key_struct| {
    $key_struct.each |$key_type, $keys| {
      $_simpkv_options = simpkv_test::simpkv_options($app_id, $key_type)

      $keys.each |$key, $key_data| {
        $_value = simpkv_test::key_value($key_data)
        if $_value =~ Undef {
          warning("Skipping '${app_id}' '${key_type}' key '${key}': Value not found in << ${key_data} >>")
          next
        }

        $_metadata = pick($key_data['metadata'], {})
        $_unique_id = "${app_id}_${key_type}_${key}"
        case simpkv_test::code_source($_unique_id) {
          'class': {
            info("Calling simpkv::put('${key}', ${_value}, ${_metadata}, ${_simpkv_options})")
            simpkv::put($key, $_value, $_metadata, $_simpkv_options)
          }
          'define': {
            simpkv_test::defines::store_key { $_unique_id:
              key            => $key,
              value          => $_value,
              metadata       => $_metadata,
              simpkv_options => $_simpkv_options
            }
          }
          'puppet_function': {
            simpkv_test::puppet_functions::store_key($key, $_value, $_metadata,
              $_simpkv_options)
          }
        }
      }
    }
  }
}
