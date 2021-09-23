# @summary Define that calls simpkv::get and validates its result
#
# Fails if validation fails.
#
# @param key
#   Name of the key to be retrieved
#
# @param expected_value
#  Expected key value
#
# @param expected_metadata
#  Expected key metadata
#
# @param simpkv_options
#   Value of the simpkv_options parameter to be used in the simpkv::get
#   function call
#
# @param binary
#  Whether the key has a binary value
#
define simpkv_test::defines::retrieve_and_verify_key(
  Simpkv_test::Key    $key,
  Any                 $expected_value,
  Variant[Hash,Undef] $expected_metadata,
  Hash                $simpkv_options,
  Boolean             $binary
) {

  $_message = "simpkv::get('${key}', ${simpkv_options})"
  info("Calling ${_message}")
  $_result = simpkv::get($key, $simpkv_options)
  simpkv_test::verify_key_data($_result, $expected_value,
    $expected_metadata, $binary, $_message)
}
