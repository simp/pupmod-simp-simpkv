class libkv_test::list inherits libkv_test::params
{
  $_expected = {
    'keys'    => {
      basename($::libkv_test::params::test_bool_key)                          => { 'value' => $::libkv_test::params::test_bool },
      basename($::libkv_test::params::test_string_key)                        => { 'value' => $::libkv_test::params::test_string },
      basename($::libkv_test::params::test_integer_key)                       => { 'value' => $::libkv_test::params::test_integer },
      basename($::libkv_test::params::test_float_key)                         => { 'value' => $::libkv_test::params::test_float },
      basename($::libkv_test::params::test_array_strings_key)                 => { 'value' => $::libkv_test::params::test_array_strings },
      basename($::libkv_test::params::test_array_integers_key)                => { 'value' => $::libkv_test::params::test_array_integers },
      basename($::libkv_test::params::test_hash_key)                          => { 'value' => $::libkv_test::params::test_hash },

      basename("${::libkv_test::params::test_bool_key}_with_meta")            => { 'value' => $::libkv_test::params::test_bool, 'metadata' => $::libkv_test::params::test_meta },
      basename("${::libkv_test::params::test_string_key}_with_meta")          => { 'value' => $::libkv_test::params::test_string, 'metadata' => $::libkv_test::params::test_meta },
      basename("${::libkv_test::params::test_integer_key}_with_meta")         => { 'value' => $::libkv_test::params::test_integer, 'metadata' => $::libkv_test::params::test_meta },
      basename("${::libkv_test::params::test_float_key}_with_meta")           => { 'value' => $::libkv_test::params::test_float, 'metadata' => $::libkv_test::params::test_meta },
      basename("${::libkv_test::params::test_array_strings_key}_with_meta")   => { 'value' => $::libkv_test::params::test_array_strings, 'metadata' => $::libkv_test::params::test_meta },
      basename("${::libkv_test::params::test_array_integers_key}_with_meta")  => { 'value' => $::libkv_test::params::test_array_integers, 'metadata' => $::libkv_test::params::test_meta },
      basename("${::libkv_test::params::test_hash_key}_with_meta")            => { 'value' => $::libkv_test::params::test_hash, 'metadata' => $::libkv_test::params::test_meta },

      'boolean_from_pfunction'                                                => { 'value' => $::libkv_test::params::test_bool }
    },
    'folders' => []
  }

  libkv_test::assert_equal(
    libkv::list($::libkv_test::params::test_keydir, $::libkv_test::params::libkv_options),
    $_expected,
    "libkv::list('${::libkv_test::params::test_keydir}')"
  )

  # top level list for the environment of the libkv backend specified by
  # $::libkv_test::params::libkv_options
  libkv_test::assert_equal(
    libkv::list('/', $::libkv_test::params::libkv_options),
    {keys => {}, folders => [  $::libkv_test::params::test_keydir ]},
    "libkv::list('/', ${::libkv_test::params::libkv_options})"
  )


  # top level list overall for the libkv backend specified by
  # $::libkv_test::params::libkv_options (i.e., the list of environments
  # for the backend)
  $_options = deep_merge($::libkv_test::params::libkv_options, { 'environment' => '' })
  libkv_test::assert_equal(
    libkv::list('/', $_options),
    {keys => {}, folders => ['production']},
    "libkv::list('/', ${_options})"
  )
}
