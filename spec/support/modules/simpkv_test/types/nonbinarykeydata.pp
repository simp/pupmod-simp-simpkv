# Information about an individual non-binary key in a keystore
type Simpkv_test::NonBinaryKeyData = Struct[{
  # Non-binary value
  value              => NotUndef,

  # Optional metadata stored with the value
  Optional[metadata] => Hash
}]

