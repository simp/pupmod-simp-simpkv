# @summary Puppet language function that simply calls simpkv::delete
#
# @param key
#   Name of the key to remove
#
# @param simpkv_options
#   Value of the simpkv_options parameter to be used in the simpkv::delete
#   function call
#
# @return [None]
#
function simpkv_test::puppet_functions::remove_key(
  Simpkv_test::Key $key,
  Hash             $simpkv_options
) {
  info("Calling simpkv::delete('${key}', ${simpkv_options})")
  simpkv::delete($key, $simpkv_options)
}
