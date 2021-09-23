# @summary Compare expected and actual folder contents and fail if they differ
#
# @param list_result
#  The actual `simpkv::list` result
#
# @param expected_keys
#  Expected key data
#
# @param expected_folders
#  Expected folder data
#
# @param message
#   Explanatory text that is added to the failure message, if the comparison
#   fails
#
# @return [None]
#
function simpkv_test::verify_folder_data(
  Variant[Hash,Undef]                                                 $list_result,
  Variant[Hash[Simpkv_test::Key,Simpkv_test::NonBinaryKeyData],Undef] $expected_keys,
  Variant[Array[String[1]],Undef]                                     $expected_folders,
  String[1]                                                           $message
) {

  info("Verifying list data for ${message}")

  if ($expected_keys =~ Undef) or ($expected_folders =~ Undef) {
    simpkv_test::assert_equal($list_result, $expected_keys, $message)
  }
  elsif ($list_result =~ Undef) or !('keys' in $list_result) or !('folders' in $list_result)
  {
    fail("${message} returned invalid value << ${list_result} >>")
  }
  else {
    $_expected_result = {
      'keys'    => $expected_keys,
      'folders' => $expected_folders
    }

    simpkv_test::assert_equal($list_result, $_expected_result, $message)
  }
}
