# Information about an individual key in a keystore
type Simpkv_test::KeyData = Struct[{
  # Either 'value' or 'file' needs to be set.
  # If both are set, 'value' will be used over 'file'.
  # If neither are set, the Simpkv_test::KeyData instance will be skipped.

  # Non-binary value
  Optional[value]    => NotUndef,

  # File containing binary value
  # - argument to binary_file, which is an absolute path or
  #   <module name>/<file name> string referencing a module file
  Optional[file]     => String[1],

  # Optional metadata stored with the value
  Optional[metadata] => Hash
}]

