class simpkv_test::delete inherits simpkv_test::params
{
  # Delete keys without metadata for the specified app_id
  $::simpkv_test::params::key_value_pairs.each |$key, $value| {
    simpkv::delete($key, $::simpkv_test::params::simpkv_options)
  }

  # Verify keys without metadata no longer exist for the specified app_id
  $::simpkv_test::params::key_value_pairs.each |$key, $value| {
    simpkv_test::assert_equal(
      simpkv::exists($key, $::simpkv_test::params::simpkv_options),
      false,
      "simpkv::exists('${key}')"
    )
  }

  # Verify keys with metadata still exist for the specified app_id
  $::simpkv_test::params::key_value_pairs.each |$key, $value| {
    simpkv_test::assert_equal(
      simpkv::exists("${key}_with_meta", $::simpkv_test::params::simpkv_options),
      true,
      "simpkv::exists('${key}_with_meta')"
    )
  }

  # Verify the key added in own Puppet function call for the specified app_id still exists
  simpkv_test::assert_equal(
    simpkv::exists(
      "${::simpkv_test::params::test_keydir}/boolean_from_pfunction",
      $::simpkv_test::params::simpkv_options
    ),
    true,
    "simpkv::exists('#{::simpkv_test::params::test_keydir}}/boolean_from_pfunction')"
  )
}
