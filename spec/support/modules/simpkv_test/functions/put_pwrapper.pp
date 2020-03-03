# Puppet language wrapper function for simpkv::put
#
# We force the user to pass in options, so that simpkv::put
# doesn't always assume the backend in `default`!
function simpkv_test::put_pwrapper(
  String $key,
  Any    $value,
  Hash   $options,
  Hash   $meta     = {},
) {

  #
  # Insert application-specific work
  #

  simpkv::put($key, $value, $meta, $options)
}
