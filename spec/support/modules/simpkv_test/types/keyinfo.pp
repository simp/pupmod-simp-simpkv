# Data structure specifying key information
#
# Keys are unique based on 3 attributes:
#  1. The backend in which they are stored
#  2. Whether they are tied to a Puppet environment or global
#  3. The key names (each of which may include a relative folder path)
#
# The grouping below was chosen to ensure uniqueness for test keys,
# **ASSUMING**, backends are uniquely mapped to the `app_id` attribute that
# will be used in the `simpkv_options` parameter of each simpkv function call.
#
# If you are mapping multiple `app_id` values to the same backend in a test,
# be sure you don't have any keys that will resolve to the same storage
# location!
#
type Simpkv_test::KeyInfo = Hash[

  # When not empty, used to set the 'app_id' attribute of the `simpkv_options`
  # parameter of each simpkv function call
  Simpkv_test::AppId,

  Struct[{
    # - Any key in 'env' is a key tied to the Puppet environment.
    # - Any key in 'global' is a global key.
    #   - For these keys, the 'global' attribute of the `simpkv_options`
    #     parameter of each simpkv function call will be automatically set
    #     to `true`.
    Optional[env]    => Simpkv_test::Keys,
    Optional[global] => Simpkv_test::Keys
  }]
]

