# @summary Puppet language function that calls simpkv::exists and validates
#   its result.
#
# Fails if validation fails.
#
# @param key
#   Name of the key/folder whose existence is to be checked
#
# @param simpkv_options
#   Value of the simpkv_options parameter to be used in the simpkv::exists
#   function call
#
# @param valid
#   Whether key/folder should exist
#
# @return [None]
#
function simpkv_test::puppet_functions::verify_name_exists(
  Simpkv_test::Key $key,
  Hash             $simpkv_options,
  Boolean          $valid
) {

  $_message = "simpkv::exists('${key}', ${simpkv_options})"
  info("Calling ${_message}")
  $_key_exists = simpkv::exists($key, $simpkv_options)
  simpkv_test::assert_equal( $_key_exists, $valid, $_message)
}
