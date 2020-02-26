define simpkv_test::defines::put(
  String $test_string    = 'dstring',
  Hash   $test_meta      = {},
  Hash   $simpkv_options  = { 'app_id' => "Simpkv_test::Defines::Put[${name}]" }
) {

  simpkv::put("from_define/${name}/string", $test_string, $test_meta,  $simpkv_options)
  simpkv_test::put_pwrapper("from_define/${name}/string_from_pfunction", $test_string, $simpkv_options, $test_meta)
}
