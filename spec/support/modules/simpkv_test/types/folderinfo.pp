# Data structure specifying folder information
#
# Folders are unique based on 3 attributes:
#  1. The backend in which they are stored
#  2. Whether they are tied to a Puppet environment or global
#  3. The folder names (each of which may include a relative path)
#
# The grouping below was chosen to ensure uniqueness for test folders,
# **ASSUMING**, backends are uniquely mapped to the `app_id` attribute that
# will be used in the `simpkv_options` parameter of each simpkv function call.
#
# If you are mapping multiple `app_id` values to the same backend in a test,
# be sure you don't have any folders that will resolve to the same storage
# location!
#
type Simpkv_test::FolderInfo = Hash[

  # When not empty, used to set the 'app_id' attribute of the `simpkv_options`
  # parameter of each simpkv function call
  Simpkv_test::AppId,

  Struct[{
    # - Any folder in 'env' is a folder tied to the Puppet environment.
    # - Any folder in 'global' is a global folder.
    #   - For these folders, the 'global' attribute of the `simpkv_options`
    #     parameter of each simpkv function call will be automatically set
    #     to `true`.
    Optional[env]    => Simpkv_test::Folders,
    Optional[global] => Simpkv_test::Folders
  }]
]
