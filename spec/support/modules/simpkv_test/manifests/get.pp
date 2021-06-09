class simpkv_test::get inherits simpkv_test::params
{
  $_empty_test_meta = {}
  $simpkv_test::params::key_value_pairs.each |$key, $value| {
    # Get and verify Puppet env keys without metadata for the specified app_id
    simpkv_test::assert_equal(
      simpkv::get($key, $simpkv_test::params::simpkv_options),
      { 'value' => $value },
      "simpkv::get('${key}', ${simpkv_test::params::simpkv_options})"
    )

    # Get and verify global keys without metadata for the specified app_id
    simpkv_test::assert_equal(
      simpkv::get($key, $simpkv_test::params::simpkv_global_options),
      { 'value' => $value },
      "simpkv::get('${key}', ${simpkv_test::params::simpkv_global_options})"
    )

    # Get and verify Puppet env keys with metadata for the specified app_id
    simpkv_test::assert_equal(
      simpkv::get("${key}_with_meta", $simpkv_test::params::simpkv_options),
      { 'value' => $value, 'metadata' => $simpkv_test::params::test_meta },
      "simpkv::get('${key}_with_meta',${simpkv_test::params::simpkv_options})"
    )
  }

  # Get key added in own Puppet function call for the specified app_id
  simpkv_test::assert_equal(
    simpkv::get(
      "${simpkv_test::params::test_keydir}/boolean_from_pfunction",
      $simpkv_test::params::simpkv_options
    ),
    { 'value' => $simpkv_test::params::test_bool },
    "simpkv::get('${simpkv_test::params::test_keydir}/boolean_from_pfunction',${simpkv_test::params::simpkv_options})"
   )
}
