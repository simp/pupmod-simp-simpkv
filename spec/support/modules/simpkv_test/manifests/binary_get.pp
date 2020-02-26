class simpkv_test::binary_get(
  Binary $test_binary = binary_file('/root/binary_data/input_data'),
  Hash   $test_meta   = { 'some' => 'metadata for binary' }
) {
  # Retrieving binary content requires careful handling, as the
  # retrieved value is a String encoded in ASCII-8BIT
  $_result1 = simpkv::get('from_class/binary')
  $_value_binary1 = Binary.new($_result1['value'], '%r')
  simpkv_test::assert_equal($_value_binary1, $test_binary, "simpkv::get('from_class/binary') content")

  $_result2 = simpkv::get('from_class/binary_with_meta')
  $_value_binary2 = Binary.new($_result2['value'], '%r')
  $_meta_binary2 = $_result2['metadata']
  simpkv_test::assert_equal($_value_binary2, $test_binary, "simpkv::get('from_class/binary_with_meta') content")
  simpkv_test::assert_equal($_meta_binary2, $test_meta, "simpkv::get('from_class/binary_with_meta' metadata)")

  # persist the binary content for external verification
  file { '/root/binary_data/retrieved_data1':
    content => $_value_binary1
  }

  file { '/root/binary_data/retrieved_data2':
    content => $_value_binary2
  }
}
