# List most of the keys/folders stored via the simpkv_test::put Class
# 
# FIXME:
# - Not checking for keys without an app_id from simpkv_test::put
# - Not checking keys from simpkv_test::defines::put Defines
class simpkv_test::list inherits simpkv_test::params
{
  $_expected_env = {
    'keys'    => {
      basename($simpkv_test::params::test_bool_key)                          => { 'value' => $simpkv_test::params::test_bool },
      basename($simpkv_test::params::test_string_key)                        => { 'value' => $simpkv_test::params::test_string },
      basename($simpkv_test::params::test_integer_key)                       => { 'value' => $simpkv_test::params::test_integer },
      basename($simpkv_test::params::test_float_key)                         => { 'value' => $simpkv_test::params::test_float },
      basename($simpkv_test::params::test_array_strings_key)                 => { 'value' => $simpkv_test::params::test_array_strings },
      basename($simpkv_test::params::test_array_integers_key)                => { 'value' => $simpkv_test::params::test_array_integers },
      basename($simpkv_test::params::test_hash_key)                          => { 'value' => $simpkv_test::params::test_hash },

      basename("${simpkv_test::params::test_bool_key}_with_meta")            => { 'value' => $simpkv_test::params::test_bool, 'metadata' => $simpkv_test::params::test_meta },
      basename("${simpkv_test::params::test_string_key}_with_meta")          => { 'value' => $simpkv_test::params::test_string, 'metadata' => $simpkv_test::params::test_meta },
      basename("${simpkv_test::params::test_integer_key}_with_meta")         => { 'value' => $simpkv_test::params::test_integer, 'metadata' => $simpkv_test::params::test_meta },
      basename("${simpkv_test::params::test_float_key}_with_meta")           => { 'value' => $simpkv_test::params::test_float, 'metadata' => $simpkv_test::params::test_meta },
      basename("${simpkv_test::params::test_array_strings_key}_with_meta")   => { 'value' => $simpkv_test::params::test_array_strings, 'metadata' => $simpkv_test::params::test_meta },
      basename("${simpkv_test::params::test_array_integers_key}_with_meta")  => { 'value' => $simpkv_test::params::test_array_integers, 'metadata' => $simpkv_test::params::test_meta },
      basename("${simpkv_test::params::test_hash_key}_with_meta")            => { 'value' => $simpkv_test::params::test_hash, 'metadata' => $simpkv_test::params::test_meta },

      'boolean_from_pfunction'                                                => { 'value' => $simpkv_test::params::test_bool }
    },
    'folders' => []
  }

  simpkv_test::assert_equal(
    simpkv::list($simpkv_test::params::test_keydir, $simpkv_test::params::simpkv_options),
    $_expected_env,
    "simpkv::list('${simpkv_test::params::test_keydir}', ${simpkv_test::params::simpkv_options})"
  )

  $_expected_global = {
    'keys'    => {
      basename($simpkv_test::params::test_bool_key)                          => { 'value' => $simpkv_test::params::test_bool },
      basename($simpkv_test::params::test_string_key)                        => { 'value' => $simpkv_test::params::test_string },
      basename($simpkv_test::params::test_integer_key)                       => { 'value' => $simpkv_test::params::test_integer },
      basename($simpkv_test::params::test_float_key)                         => { 'value' => $simpkv_test::params::test_float },
      basename($simpkv_test::params::test_array_strings_key)                 => { 'value' => $simpkv_test::params::test_array_strings },
      basename($simpkv_test::params::test_array_integers_key)                => { 'value' => $simpkv_test::params::test_array_integers },
      basename($simpkv_test::params::test_hash_key)                          => { 'value' => $simpkv_test::params::test_hash }
    },
    'folders' => []
  }

  simpkv_test::assert_equal(
    simpkv::list($simpkv_test::params::test_keydir, $simpkv_test::params::simpkv_global_options),
    $_expected_global,
    "simpkv::list('${simpkv_test::params::test_keydir}', ${simpkv_test::params::simpkv_global_options})"
  )

  # top level list for the Puppet env of the simpkv backend specified by
  # $simpkv_test::params::simpkv_options
  simpkv_test::assert_equal(
    simpkv::list('/', $simpkv_test::params::simpkv_options),
    {keys => {}, folders => [  $simpkv_test::params::test_keydir ]},
    "simpkv::list('/', ${simpkv_test::params::simpkv_options})"
  )

  # top level list for global keys of the simpkv backend specified by
  # $simpkv_test::params::simpkv_options
  simpkv_test::assert_equal(
    simpkv::list('/', $simpkv_test::params::simpkv_global_options),
    {keys => {}, folders => [  $simpkv_test::params::test_keydir ]},
    "simpkv::list('/', ${simpkv_test::params::simpkv_global_options})"
  )

  # top level list for global keys for default backend
  $_default_global_options = { 'global' => true }
  simpkv_test::assert_equal(
    simpkv::list('/', $_default_global_options),
    {keys => {}, folders => []},
    "simpkv::list('/', ${_default_global_options})"
  )
}
