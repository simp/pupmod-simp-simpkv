require 'json'
require 'base64'

module Acceptance; end
module Acceptance::Helpers; end

module Acceptance::Helpers::Utils

  # @return key string persisted to the backend for the key_data
  #
  # FIXME: If the data is binary and specified by the 'file' attribute,
  #        this method ASSUMES the file is in the simpkv_test module
  #
  # @param key_data
  def key_data_string(key_data)
   key_hash = {}
   if key_data.key?('value')
     key_hash['value'] = key_data['value']
   elsif key_data.key?('file')
     simpkv_test_files = File.join(__dir__, '../../support/modules/simpkv_test/files')
     value = IO.read( key_data['file'].gsub('simpkv_test', "#{simpkv_test_files}") )
     value.force_encoding('ASCII-8BIT')

     encoded_value = Base64.strict_encode64(value)
     key_hash['value'] = encoded_value
     key_hash['encoding'] = 'base64'
     key_hash['original_encoding'] = 'ASCII-8BIT'
   end

   if key_data.key?('metadata')
     key_hash['metadata'] = key_data['metadata']
   else
     key_hash['metadata'] = {}
   end

   key_hash.to_json
  end

end

