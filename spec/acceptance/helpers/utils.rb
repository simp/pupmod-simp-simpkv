require 'json'
require 'base64'

module Acceptance; end
module Acceptance::Helpers; end

module Acceptance::Helpers::Utils

  # @return Backend configuration Hash for the backend corresponding to app_id and
  #   plugin_type
  #
  # FIXME: Selects the backend based on an exact match with app_id. Should use
  #   the fuzzy matching logic built into the simpkv API.
  #
  # @param app_id The app_id for a key or '', if none specified
  #
  # @param plugin_type The plugin type to verify or nil if no verification
  #   is required
  #
  # @param backend_hiera Hash of backend configuration ('simpkv::options' Hash)
  #
  # @raise RuntimeError if no backend for the app_id exists in backend_hiera
  #
  def backend_config_for_app_id(app_id, plugin_type, backend_hiera)
    config = {}

    if backend_hiera['simpkv::options']['backends'].key?(app_id)
      if backend_hiera['simpkv::options']['backends'][app_id].is_a?(String)
        # Assume this is an alias for simpkv::backend::<app_id>
        config = backend_hiera["simpkv::backend::#{app_id}"]
      else
        backend_hiera['simpkv::options']['backends'][app_id]
      end
    elsif backend_hiera['simpkv::options']['backends'].key?('default')
      if backend_hiera['simpkv::options']['backends']['default'].is_a?(String)
        # Assume this is an alias for simpkv::backend::default
        config = backend_hiera['simpkv::backend::default']
      else
        config = backend_hiera['simpkv::options']['backends']['default']
      end
    end

    if config.empty? || ( !plugin_type.nil? && (config['type'] != plugin_type) )
      fail("No '#{plugin_type}' backend found for #{app_id}")
    end

    config
  end

  # @return key string persisted to the backend for the key_data
  #
  # FIXME: If the data is binary and specified by the 'file' attribute,
  #        this method *ASSUMES *the file is in the simpkv_test module
  #
  # @param key_data Hash with key data corresponding to Simpkv_test::KeyData
  #
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

