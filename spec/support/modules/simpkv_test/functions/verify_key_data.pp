# @summary Compare expected and actual key data and fail if they differ
#
# @param get_result
#  The actual `simpkv::get` result
#
# @param expected_value
#  Expected key value
#
# @param expected_metadata
#  Expected key metadata
#
# @param binary
#  Whether the key has a binary value
#
# @param message
#   Explanatory text that is added to the failure message, if the comparison
#   fails
#
# @return [None]
#
function simpkv_test::verify_key_data(
  Variant[Hash,Undef] $get_result,
  Any                 $expected_value,
  Variant[Hash,Undef] $expected_metadata,
  Boolean             $binary,
  String[1]           $message
) {

  info("Verifying key data for ${message}")

  if $expected_value =~ Undef {
    simpkv_test::assert_equal($get_result, $expected_value, $message)
  }
  elsif ($get_result =~ Undef) or !('value' in $get_result) {
    fail("${message} returned invalid value << ${get_result} >>")
  }
  elsif $binary {
    $_value_binary = Binary.new($get_result['value'], '%r')
    simpkv_test::assert_equal($_value_binary, $expected_value,
      "${message} content")

    simpkv_test::assert_equal($get_result['metadata'], $expected_metadata,
      "${message} metadata")
  }
  else {
    if $expected_metadata {
      $_expected_result = {
        'value'    => $expected_value,
        'metadata' => $expected_metadata
      }
    }
    else
    {
      $_expected_result = { 'value' => $expected_value }
    }

    simpkv_test::assert_equal( $get_result, $_expected_result, $message)
  }
}
