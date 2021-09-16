# @summary Returns key value specified by `$key_data`
#
# Transforms to Binary as necessary, or undef if the value cannot be determined.
#
# @param key_data
#  Key specification
#
# @return [Any]
#
function simpkv_test::key_value(
  Simpkv_test::KeyData $key_data
) {

  if 'value' in $key_data {
    $key_data['value']
  }
  elsif 'file' in $key_data {
    binary_file($key_data['file'])
  }
  else {
    undef
  }
}
