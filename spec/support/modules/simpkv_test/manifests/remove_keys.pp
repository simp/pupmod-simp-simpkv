# @summary Remove keys using simpkv::delete
#
# @param keyname_info
#   Info specifying the names of keys to remove
#
class simpkv_test::remove_keys (
  Simpkv_test::NameInfo $keyname_info
) {

  $keyname_info.each |$app_id, $key_struct| {
    $key_struct.each |$key_type, $keynames| {
      $_simpkv_options = simpkv_test::simpkv_options($app_id, $key_type)

      $keynames.each |$key| {
        $_unique_id = "${app_id}_${key_type}_${key}"
        case simpkv_test::code_source($_unique_id) {
          'class': {
            info("Calling simpkv::delete('${key}', ${_simpkv_options})")
            simpkv::delete($key, $_simpkv_options)
          }
          'define': {
            simpkv_test::defines::remove_key { $_unique_id:
              key            => $key,
              simpkv_options => $_simpkv_options
            }
          }
          'puppet_function': {
            simpkv_test::puppet_functions::remove_key($key, $_simpkv_options)
          }
        }
      }
    }
  }
}
