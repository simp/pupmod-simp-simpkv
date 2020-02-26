class simpkv_test::list inherits simpkv_test::params
{
  $_expected = {
    'keys'    => {
      basename($::simpkv_test::params::test_bool_key)                          => { 'value' => $::simpkv_test::params::test_bool },
      basename($::simpkv_test::params::test_string_key)                        => { 'value' => $::simpkv_test::params::test_string },
      basename($::simpkv_test::params::test_integer_key)                       => { 'value' => $::simpkv_test::params::test_integer },
      basename($::simpkv_test::params::test_float_key)                         => { 'value' => $::simpkv_test::params::test_float },
      basename($::simpkv_test::params::test_array_strings_key)                 => { 'value' => $::simpkv_test::params::test_array_strings },
      basename($::simpkv_test::params::test_array_integers_key)                => { 'value' => $::simpkv_test::params::test_array_integers },
      basename($::simpkv_test::params::test_hash_key)                          => { 'value' => $::simpkv_test::params::test_hash },

      basename("${::simpkv_test::params::test_bool_key}_with_meta")            => { 'value' => $::simpkv_test::params::test_bool, 'metadata' => $::simpkv_test::params::test_meta },
      basename("${::simpkv_test::params::test_string_key}_with_meta")          => { 'value' => $::simpkv_test::params::test_string, 'metadata' => $::simpkv_test::params::test_meta },
      basename("${::simpkv_test::params::test_integer_key}_with_meta")         => { 'value' => $::simpkv_test::params::test_integer, 'metadata' => $::simpkv_test::params::test_meta },
      basename("${::simpkv_test::params::test_float_key}_with_meta")           => { 'value' => $::simpkv_test::params::test_float, 'metadata' => $::simpkv_test::params::test_meta },
      basename("${::simpkv_test::params::test_array_strings_key}_with_meta")   => { 'value' => $::simpkv_test::params::test_array_strings, 'metadata' => $::simpkv_test::params::test_meta },
      basename("${::simpkv_test::params::test_array_integers_key}_with_meta")  => { 'value' => $::simpkv_test::params::test_array_integers, 'metadata' => $::simpkv_test::params::test_meta },
      basename("${::simpkv_test::params::test_hash_key}_with_meta")            => { 'value' => $::simpkv_test::params::test_hash, 'metadata' => $::simpkv_test::params::test_meta },

      'boolean_from_pfunction'                                                => { 'value' => $::simpkv_test::params::test_bool }
    },
    'folders' => []
  }

  simpkv_test::assert_equal(
    simpkv::list($::simpkv_test::params::test_keydir, $::simpkv_test::params::simpkv_options),
    $_expected,
    "simpkv::list('${::simpkv_test::params::test_keydir}')"
  )

  # top level list for the environment of the simpkv backend specified by
  # $::simpkv_test::params::simpkv_options
  simpkv_test::assert_equal(
    simpkv::list('/', $::simpkv_test::params::simpkv_options),
    {keys => {}, folders => [  $::simpkv_test::params::test_keydir ]},
    "simpkv::list('/', ${::simpkv_test::params::simpkv_options})"
  )


  # top level list overall for the simpkv backend specified by
  # $::simpkv_test::params::simpkv_options (i.e., the list of environments
  # for the backend)
  $_options = deep_merge($::simpkv_test::params::simpkv_options, { 'environment' => '' })
  simpkv_test::assert_equal(
    simpkv::list('/', $_options),
    {keys => {}, folders => ['production']},
    "simpkv::list('/', ${_options})"
  )
}
