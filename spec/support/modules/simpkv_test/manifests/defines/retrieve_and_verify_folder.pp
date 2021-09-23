# @summary Define that calls simpkv::list and validates its result
#
# Fails if validation fails.
#
# @param folder
#   Name of the folder to be listed
#
# @param expected_keys
#  Expected key data
#
# @param expected_folders
#  Expected folder data
#
# @param simpkv_options
#   Value of the simpkv_options parameter to be used in the simpkv::list
#   function call
#
define simpkv_test::defines::retrieve_and_verify_folder(
  Simpkv_test::Key                                                    $folder,
  Variant[Hash[Simpkv_test::Key,Simpkv_test::NonBinaryKeyData],Undef] $expected_keys,
  Variant[Array[String[1]],Undef]                                     $expected_folders,
  Hash                                                                $simpkv_options = {}
) {

  $_message = "simpkv::list('${folder}', ${simpkv_options})"
  info("Calling ${_message}")

  $_result = simpkv::list($folder, $simpkv_options)
  simpkv_test::verify_folder_data($_result, $expected_keys, $expected_folders, $_message)
}
