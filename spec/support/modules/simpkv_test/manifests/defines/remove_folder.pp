# @summary Define that simply calls simpkv::deletetree
#
# @param folder
#   Name of the folder to remove
#
# @param simpkv_options
#   Value of the simpkv_options parameter to be used in the simpkv::deletetree
#   function call
#
define simpkv_test::defines::remove_folder(
  Simpkv_test::Key $folder,
  Hash             $simpkv_options  = {}
) {

  info("Calling simpkv::deletetree('${folder}', ${simpkv_options})")
  simpkv::deletetree($folder, $simpkv_options)
}
