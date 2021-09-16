# @summary Remove folders using simpkv::deletetree
#
# @param foldername_info
#   Info specifying the names of the folders to remove
#
class simpkv_test::remove_folders (
  Simpkv_test::NameInfo $foldername_info
) {

  $foldername_info.each |$app_id, $folder_struct| {
    $folder_struct.each |$folder_type, $foldernames| {
      $_simpkv_options = simpkv_test::simpkv_options($app_id, $folder_type)

      $foldernames.each |$folder| {
        $_unique_id = "${app_id}_${folder_type}_${folder}"
        case simpkv_test::code_source($_unique_id) {
          'class': {
            info("Calling simpkv::deletetree('${folder}', ${_simpkv_options})")
            simpkv::deletetree($folder, $_simpkv_options)
          }
          'define': {
            simpkv_test::defines::remove_folder { $_unique_id:
              folder         => $folder,
              simpkv_options => $_simpkv_options
            }
          }
          'puppet_function': {
            simpkv_test::puppet_functions::remove_folder($folder, $_simpkv_options)
          }
        }
      }
    }
  }
}
