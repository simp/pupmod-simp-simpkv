# @summary Compare 2 values and fail if they differ
#
# @param actual
#   Actual value
#
# @param expected
#   Expected value
#
# @param message
#   Explanatory text that is added to the failure message
#
# @return [None]
#
function simpkv_test::assert_equal(
  Any    $actual,
  Any    $expected,
  String $message
) {

  info("Checking results for ${message}")

  if ($actual == $expected) {
    if $actual =~ Binary {
     info("Actual binary results match expected")
    }
    else {
     info("Actual results match expected '${expected}'")
    }
  }
  else {
    fail("Expected '${expected}'; got '${actual}' for ${message}")
  }
}
