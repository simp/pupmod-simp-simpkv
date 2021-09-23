# @summary "Randomly" assigns the code source from which a simpkv function will
#   be called.
#
# @param id
#  Id of the key/folder used in the simpkv function
#
#  - Used as the random generator seed
#
# @return [Enum['class', 'define', 'puppet_function']]
#
function simpkv_test::code_source(String $id) {

  $_values = [ 'class', 'define', 'puppet_function' ]
  $_index = seeded_rand(3, $id)
  $_values[$_index]
}
