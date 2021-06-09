# Delete a subset of keys from the backend mapped to an app_id and verify
# only those keys were deleted
class simpkv_test::delete inherits simpkv_test::params
{
  # Delete Puppet env keys without metadata for the specified app_id
  $simpkv_test::params::key_value_pairs.each |$key, $value| {
    simpkv::delete($key, $simpkv_test::params::simpkv_options)
  }

  # Verify Puppet env keys without metadata no longer exist for the specified
  # app_id
  $simpkv_test::params::key_value_pairs.each |$key, $value| {
    simpkv_test::assert_equal(
      simpkv::exists($key, $simpkv_test::params::simpkv_options),
      false,
      "simpkv::exists('${key}', ${simpkv_test::params::simpkv_options})"
    )
  }

  # Verify global keys without still exist for the specified app_id
  $simpkv_test::params::key_value_pairs.each |$key, $value| {
    simpkv_test::assert_equal(
      simpkv::exists($key, $simpkv_test::params::simpkv_global_options),
      true,
      "simpkv::exists('${key}', ${simpkv_test::params::simpkv_global_options})"
    )
  }

  # Verify Puppet env keys with metadata still exist for the specified app_id
  $simpkv_test::params::key_value_pairs.each |$key, $value| {
    simpkv_test::assert_equal(
      simpkv::exists("${key}_with_meta", $simpkv_test::params::simpkv_options),
      true,
      "simpkv::exists('${key}_with_meta', ${simpkv_test::params::simpkv_options})"
    )
  }

  # Verify the Puppet env key added in a Puppet function call for the specified
  # app_id still exists
  simpkv_test::assert_equal(
    simpkv::exists(
      "${simpkv_test::params::test_keydir}/boolean_from_pfunction",
      $simpkv_test::params::simpkv_options
    ),
    true,
    "simpkv::exists('${simpkv_test::params::test_keydir}}/boolean_from_pfunction',${simpkv_test::params::simpkv_options})"
  )
}
