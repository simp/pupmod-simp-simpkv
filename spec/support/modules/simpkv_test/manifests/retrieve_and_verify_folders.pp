# @summary Retrieve folder lists with simpkv::list and verify the result
#
# @param valid_folder_info
#   Info specifying folders that are expected to be present in the
#   keystore and their contents
#
# @param invalid_folder_info
#   Info specifying folders that are not expected to be present in
#   the keystore
#
class simpkv_test::retrieve_and_verify_folders (
  Simpkv_test::FolderInfo $valid_folder_info,
  Simpkv_test::FolderInfo $invalid_folder_info
) {
  $valid_folder_info.each |$app_id, $folder_struct| {
    $folder_struct.each |$folder_type, $folders| {
      $_simpkv_options = simpkv_test::simpkv_options($app_id, $folder_type)

      $folders.each |$folder, $folder_data| {
        $_expected_keys = pick($folder_data['keys'], {})
        $_expected_folders = pick($folder_data['folders'], [])
        $_unique_id = "${app_id}_${folder_type}_${folder}"
        case simpkv_test::code_source($_unique_id) {
          'class': {
            $_message = "simpkv::list('${folder}', ${_simpkv_options})"
            info("Calling ${_message}")
            $_result = simpkv::list($folder, $_simpkv_options)
            simpkv_test::verify_folder_data($_result, $_expected_keys,
              $_expected_folders, $_message)
          }
          'define': {
            simpkv_test::defines::retrieve_and_verify_folder { $_unique_id:
              folder           => $folder,
              expected_keys    => $_expected_keys,
              expected_folders => $_expected_folders,
              simpkv_options   => $_simpkv_options
            }
          }
          'puppet_function': {
            simpkv_test::puppet_functions::retrieve_and_verify_folder($folder,
              $_expected_keys, $_expected_folders, $_simpkv_options)
          }
        }
      }
    }
  }

  $invalid_folder_info.each |$app_id, $folder_struct| {
    $folder_struct.each |$folder_type, $folders| {
      # Enable 'softfail', so failure returns Undef instead of failing catalog
      # compilation
      $_simpkv_options = simpkv_test::simpkv_options($app_id, $folder_type,
        { 'softfail' => true })

      $folders.each |$folder, $folder_data| {
        $_expected_keys = undef
        $_expected_folders = undef
        $_unique_id = "${app_id}_${folder_type}_${folder}"
        case simpkv_test::code_source($_unique_id) {
          'class': {
            $_message = "simpkv::list('${folder}', ${_simpkv_options})"
            info("Calling ${_message}")
            $_result = simpkv::list($folder, $_simpkv_options)
            simpkv_test::verify_folder_data( $_result, $_expected_keys,
              $_expected_folders, $_message)
          }
          'define': {
            simpkv_test::defines::retrieve_and_verify_folder { $_unique_id:
              folder           => $folder,
              expected_keys    => $_expected_keys,
              expected_folders => $_expected_folders,
              simpkv_options   => $_simpkv_options
            }
          }
          'puppet_function': {
            simpkv_test::puppet_functions::retrieve_and_verify_folder(
              $folder, $_expected_keys, $_expected_folders, $_simpkv_options)
          }
        }
      }
    }
  }
}
