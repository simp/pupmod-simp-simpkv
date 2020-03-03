class simpkv_test::deletetree inherits simpkv_test::params
{
  # Delete parent dir of keys for the specified app_id
  simpkv::deletetree($::simpkv_test::params::test_keydir, $::simpkv_test::params::simpkv_options)

  # Verify keys with and without metadata no longer exist for the specified app_id
  $::simpkv_test::params::key_value_pairs.each |$key, $value| {
    simpkv_test::assert_equal(
      simpkv::exists($key, $::simpkv_test::params::simpkv_options),
      false,
      "simpkv::exists('${key}')"
    )

    simpkv_test::assert_equal(
      simpkv::exists("${key}_with_meta", $::simpkv_test::params::simpkv_options),
      false,
      "simpkv::exists('${key}_with_meta')"
    )
  }

  # Verify the key added in own Puppet function call for the specified app_id no longer exists
  simpkv_test::assert_equal(
    simpkv::exists(
      "${::simpkv_test::params::test_keydir}/boolean_from_pfunction",
      $::simpkv_test::params::simpkv_options
    ),
    false,
    "simpkv::exists('#{::simpkv_test::params::test_keydir}}/boolean_from_pfunction')"
  )
}
