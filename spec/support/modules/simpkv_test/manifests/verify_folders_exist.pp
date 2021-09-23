# @summary Check for the existence of folders using simpkv::exists
#
# @param valid_foldername_info
#   Info specifying names of folder that are expected to be present in the
#   keystore
#
# @param invalid_foldername_info
#   Info specifying names of folder that are not expected to be present in
#   the keystore
#
class simpkv_test::verify_folders_exist (
  Simpkv_test::NameInfo $valid_foldername_info,
  Simpkv_test::NameInfo $invalid_foldername_info
) {

  $_folders_to_check = {
    true  => $valid_foldername_info,
    false => $invalid_foldername_info
  }

  $_folders_to_check.each |$valid, $folder_info| {
    $folder_info.each |$app_id, $folder_struct| {
      $folder_struct.each |$folder_type, $foldernames| {
        $_simpkv_options = simpkv_test::simpkv_options($app_id, $folder_type)

        $foldernames.each |$folder| {
          $_unique_id = "${app_id}_${folder_type}_${folder}"
          case simpkv_test::code_source($_unique_id) {
            'class': {
              $_message = "simpkv::exists('${folder}', ${_simpkv_options})"
              info("Calling ${_message}")
              $_folder_exists = simpkv::exists($folder, $_simpkv_options)
              simpkv_test::assert_equal($_folder_exists, $valid, $_message)
            }
            'define': {
              simpkv_test::defines::verify_name_exists{ $_unique_id:
                key            => $folder,
                simpkv_options => $_simpkv_options,
                valid          => $valid
              }
            }
            'puppet_function': {
              simpkv_test::puppet_functions::verify_name_exists($folder,
                $_simpkv_options, $valid)
            }
          }
        }
      }
    }
  }
}
