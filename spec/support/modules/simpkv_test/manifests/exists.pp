class simpkv_test::exists inherits simpkv_test::params
{
  # Check for keys with and without metadata for the specified app_id
  $::simpkv_test::params::key_value_pairs.each |$key, $value| {
    simpkv_test::assert_equal(
      simpkv::exists($key, $::simpkv_test::params::simpkv_options),
      true,
      "simpkv::exists('${key}')"
    )

    simpkv_test::assert_equal(
      simpkv::exists("${key}_with_meta", $::simpkv_test::params::simpkv_options),
      true,
      "simpkv::exists('${key}_with_meta')"
    )
  }


  # Check for the key added in own Puppet function call for the specified app_id
  simpkv_test::assert_equal(
    simpkv::exists(
      "${::simpkv_test::params::test_keydir}/boolean_from_pfunction",
      $::simpkv_test::params::simpkv_options
    ),
    true,
    "simpkv::exists('#{::simpkv_test::params::test_keydir}}/boolean_from_pfunction')"
  )

  # Check for the key added in own Puppet function call without the specified app_id.
  # Should be in default backend but not the backend for the app_id.
  $_empty_simpkv_options = {}
  simpkv_test::assert_equal(
    simpkv::exists(
      "${::simpkv_test::params::test_keydir}/boolean_from_pfunction_no_app_id",
      $_empty_simpkv_options
    ),
    true,
    "simpkv::exists('#{::simpkv_test::params::test_keydir}}/boolean_from_pfunction_no_appid') default backend"
  )

  simpkv_test::assert_equal(
    simpkv::exists(
      "${::simpkv_test::params::test_keydir}/boolean_from_pfunction_no_app_id",
      $::simpkv_test::params::simpkv_options
    ),
    false,
    "simpkv::exists('#{::simpkv_test::params::test_keydir}}/boolean_from_pfunction_no_appid') backend for app_id"
  )
}
