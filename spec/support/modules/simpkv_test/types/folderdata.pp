# Information about an individual folder in a keystore
type Simpkv_test::FolderData = Struct[{
  # Info about keys in the directory
  # - Currently restricted to keys with non-binary data because of
  #   test manifest limitations
  Optional[keys]    => Hash[Simpkv_test::Key,Simpkv_test::NonBinaryKeyData],

  # List of subfolder names
  Optional[folders] => Array[String[1]]
}]
