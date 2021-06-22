# Delete parent dirs of Puppet env and global keys from the backend mapped to
# an app_id and verify all keys were deleted
class simpkv_test::deletetree inherits simpkv_test::params
{
  # Delete parent dir of global keys for the specified app_id
  simpkv::deletetree($simpkv_test::params::test_keydir, $simpkv_test::params::simpkv_global_options)

  # Verify global keys no longer exist for the specified app_id
  $simpkv_test::params::key_value_pairs.each |$key, $value| {
    simpkv_test::assert_equal(
      simpkv::exists($key, $simpkv_test::params::simpkv_global_options),
      false,
      "simpkv::exists('${key}', ${simpkv_test::params::simpkv_global_options})"
    )
  }

  # Delete parent dir of Puppet env keys for the specified app_id
  simpkv::deletetree($simpkv_test::params::test_keydir, $simpkv_test::params::simpkv_options)

  # Verify Puppet env keys with and without metadata no longer exist for the specified app_id
  $simpkv_test::params::key_value_pairs.each |$key, $value| {
    simpkv_test::assert_equal(
      simpkv::exists($key, $simpkv_test::params::simpkv_options),
      false,
      "simpkv::exists('${key}', ${simpkv_test::params::simpkv_options})"
    )

    simpkv_test::assert_equal(
      simpkv::exists("${key}_with_meta", $simpkv_test::params::simpkv_options),
      false,
      "simpkv::exists('${key}_with_meta', ${simpkv_test::params::simpkv_options})"
    )
  }

  # Verify the key added in own Puppet function call for the specified app_id no longer exists
  simpkv_test::assert_equal(
    simpkv::exists(
      "${simpkv_test::params::test_keydir}/boolean_from_pfunction",
      $simpkv_test::params::simpkv_options
    ),
    false,
    "simpkv::exists('${simpkv_test::params::test_keydir}}/boolean_from_pfunction',${simpkv_test::params::simpkv_options})"
  )
}
