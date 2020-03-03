class simpkv_test::get inherits simpkv_test::params
{
  # Get keys with and without metadata for the specified app_id
  $_empty_test_meta = {}
  $::simpkv_test::params::key_value_pairs.each |$key, $value| {
    simpkv_test::assert_equal(
      simpkv::get($key, $::simpkv_test::params::simpkv_options),
      { 'value' => $value },
      "simpkv::get('${key}')"
    )

    simpkv_test::assert_equal(
      simpkv::get("${key}_with_meta", $::simpkv_test::params::simpkv_options),
      { 'value' => $value, 'metadata' => $::simpkv_test::params::test_meta },
      "simpkv::get('${key}_with_meta')"
    )
  }

  # Get key added in own Puppet function call for the specified app_id
  simpkv_test::assert_equal(
    simpkv::get(
      "${::simpkv_test::params::test_keydir}/boolean_from_pfunction",
      $::simpkv_test::params::simpkv_options
    ),
    { 'value' => $::simpkv_test::params::test_bool },
    "simpkv::get('${::simpkv_test::params::test_keydir}/boolean_from_pfunction')"
   )
}
