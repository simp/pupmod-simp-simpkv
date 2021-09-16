# Key or folder name
#
# The regex is not perfect (doesn't catch sequences that look
# like relative paths), but sufficient for this test module.
type Simpkv_test::Key = Pattern['^[a-z0-9._:\-\/]+$']
