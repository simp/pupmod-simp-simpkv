# Check for the existance of keys stored via the simpkv_test::put Class
#
# FIXME: Not checking keys from simpkv_test::defines::put Defines
#
class simpkv_test::exists inherits simpkv_test::params
{
  # Check for keys with and without metadata for the specified app_id
  $simpkv_test::params::key_value_pairs.each |$key, $value| {
    # Puppet env keys without metadata
    simpkv_test::assert_equal(
      simpkv::exists($key, $simpkv_test::params::simpkv_options),
      true,
      "simpkv::exists('${key}', ${simpkv_test::params::simpkv_options})"
    )

    # Puppet env keys witht metadata
    simpkv_test::assert_equal(
      simpkv::exists("${key}_with_meta", $simpkv_test::params::simpkv_options),
      true,
      "simpkv::exists('${key}_with_meta', ${simpkv_test::params::simpkv_options})"
    )

    # global keys without metadata
    simpkv_test::assert_equal(
      simpkv::exists("${key}", $simpkv_test::params::simpkv_global_options),
      true,
      "simpkv::exists('${key}_with_meta', ${simpkv_test::params::simpkv_global_options})"
    )
  }


  # Check for the Puppet env key added in a Puppet function call for the
  # specified app_id.
  simpkv_test::assert_equal(
    simpkv::exists(
      "${simpkv_test::params::test_keydir}/boolean_from_pfunction",
      $simpkv_test::params::simpkv_options
    ),
    true,
    "simpkv::exists('${simpkv_test::params::test_keydir}}/boolean_from_pfunction', ${simpkv_test::params::simpkv_options})"
  )

  # Check for the Puppet env key added in a Puppet function call without the
  # specified app_id. Should be in default backend but not the backend for the
  # app_id.
  $_empty_simpkv_options = {}
  simpkv_test::assert_equal(
    simpkv::exists(
      "${simpkv_test::params::test_keydir}/boolean_from_pfunction_no_app_id",
      $_empty_simpkv_options
    ),
    true,
    "simpkv::exists('${simpkv_test::params::test_keydir}}/boolean_from_pfunction_no_appid')"
  )
}
