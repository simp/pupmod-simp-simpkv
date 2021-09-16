# Data structure specifying simply key/folder names
#
# Key/folder names are unique based on 3 attributes:
#  1. The backend in which they are stored
#  2. Whether they are tied to a Puppet environment or global
#  3. The key/folder names (each of which may include a relative folder path)
#
# The grouping below was chosen to ensure uniqueness for test key/folder names,
# **ASSUMING**, backends are uniquely mapped to the `app_id` attribute that
# will be used in the `simpkv_options` parameter of each simpkv function call.
#
# If you are mapping multiple `app_id` values to the same backend in a test,
# be sure you don't have any keys/folders that will resolve to the same storage
# location!
#
type Simpkv_test::NameInfo = Hash[

  # When not empty, used to set the 'app_id' attribute of the `simpkv_options`
  # parameter of each simpkv function call
  Simpkv_test::AppId,

  Struct[{
    # - Any key/folder in 'env' is tied to the Puppet environment.
    # - Any key/folder in 'global' is global
    #   - For these entities, the 'global' attribute of the `simpkv_options`
    #     parameter of each simpkv function call will be automatically set
    #     to `true`.
    Optional[env]    => Array[Simpkv_test::Key],
    Optional[global] => Array[Simpkv_test::Key]
  }]
]

