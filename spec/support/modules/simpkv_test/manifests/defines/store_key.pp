# @summary Define that simply calls simpkv::put
#
# @param key
#   Name of the key to store
#
# @param value
#   Value to store
#
# @param metadata
#   Metadata to store
#
# @param simpkv_options
#   Value of the simpkv_options parameter to be used in the simpkv::put
#   function call
#
define simpkv_test::defines::store_key(
  Simpkv_test::Key $key,
  NotUndef         $value,
  Hash             $metadata        = {},
  Hash             $simpkv_options  = {}
) {

  info("Calling simpkv::put('${key}', ${value}, ${metadata}, ${simpkv_options})")
  simpkv::put($key, $value, $metadata,  $simpkv_options)
}
