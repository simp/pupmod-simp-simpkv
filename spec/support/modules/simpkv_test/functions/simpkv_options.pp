# @summary Generates simpkv_options Hash for use in simpkv function calls
#
# @param app_id
#  `app_id` to be set in the simpkv_options Hash
#
#  - Ignored when an empty string
#
# @param key_type
#   The key/folder type
#
#   - 'env':  key/folder is tied to a Puppet environment
#   - 'global': key/folder is global
#
# @param other_options
#   Other options to be set in the returned simpkv_options Hash
#
# @return [Hash]
#
function simpkv_test::simpkv_options(
  Simpkv_test::AppId    $app_id,
  Enum['env', 'global'] $key_type,
  Hash                  $other_options = {}
) {
  if empty($app_id) {
    if $key_type == 'env' {
      $_simpkv_options = $other_options
    }
    else {
      $_simpkv_options = $other_options.merge({ 'global' => true })
    }
  }
  else {
    if $key_type == 'env' {
      $_simpkv_options = $other_options.merge({ 'app_id' => $app_id })
    }
    else {
      $_simpkv_options = $other_options.merge({
        'app_id' => $app_id,
        'global' => true
      })
    }
  }

  $_simpkv_options
}
