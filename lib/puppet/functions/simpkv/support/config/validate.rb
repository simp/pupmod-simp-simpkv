# Validate backend configuration
#
# @author https://github.com/simp/pupmod-simp-simpkv/graphs/contributors
#
Puppet::Functions.create_function(:'simpkv::support::config::validate') do
  # @param options Hash that specifies simpkv backend options
  #
  # @param backends List of backends for which plugins have been successfully
  #   loaded.
  #
  # @return [Nil]
  # @raise ArgumentError if a backend has not been specified, appropriate
  #   configuration for a specified backend cannot be found, or different
  #   backend configurations are provided for the same ['type', 'id'] pair.
  #
  dispatch :validate do
    # Can't use a fully-defined Struct, since the parts of the Hash
    # specifying individual plugin config may have plugin-specific keys
    param 'Hash',  :options
    param 'Array', :backends
  end

  def validate(options, backends)
    unless options.key?('backend')
      msg = "'backend' not specified in simpkv configuration: #{options}"
      raise ArgumentError, msg
    end

    backend = options['backend']

    unless options.key?('backends')
      msg = "'backends' not specified in simpkv configuration: #{options}"
      raise ArgumentError, msg
    end

    unless options['backends'].is_a?(Hash)
      msg = "'backends' in simpkv configuration is not a Hash: #{options}"
      raise ArgumentError, msg
    end

    unless options['backends'].key?(options['backend']) &&
           options['backends'][backend].is_a?(Hash) &&
           options['backends'][backend].key?('id') &&
           options['backends'][backend].key?('type')

      msg = "No simpkv backend '#{backend}' with 'id' and 'type' attributes has been configured: #{options}"
      raise ArgumentError, msg
    end

    unless backends.include?(options['backends'][backend]['type'])
      msg = "simpkv backend plugin '#{options['backends'][backend]['type']}' not available. Valid plugins = #{backends}"
      raise ArgumentError, msg
    end

    # plugin instances are uniquely defined by the <type,id> pair, not name.
    # Make sure all backend configurations for a <type,id> pair have the same
    # configuration.
    backend_instances = {}
    options['backends'].each_value do |config|
      instance_id = "#{config['type']}/#{config['id']}"
      if backend_instances.key?(instance_id)
        unless backend_instances[instance_id] == config
          msg = 'simpkv config contains different backend configs for ' \
                "type=#{config['type']} id=#{config['id']}: #{options}"
          raise ArgumentError, msg
        end
      else
        backend_instances[instance_id] = config
      end
    end
  end
end
