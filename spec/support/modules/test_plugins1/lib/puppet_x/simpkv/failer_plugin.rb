# This is a bad-behaving plugin that will raise an exception
# during a public plugin API method to support testing. It can
# also be configured to raise an exception in its configure().
#

# Each plugin **MUST** be an anonymous class accessible only through
# a `plugin_class` local variable.
Class.new do
  ###### Public Plugin API ######

  # Construct an instance of this plugin setting its instance name
  #
  # @param name Name to ascribe to this plugin instance
  #
  def initialize(name)
    @name = name
    Puppet.debug("#{@name} simpkv plugin constructed")
  end

  # Configure this plugin instance using global and plugin-specific
  # configuration found in options
  #
  # The plugin-specific configuration will be found in
  # `options['backends'][ options['backend'] ]`
  #
  # @param name Name to ascribe to this plugin instance
  # @param options Hash of global simpkv and backend-specific options
  # @raise RuntimeError if any required configuration is missing from options
  #   or this object can't set up any stateful objects it needs to do its work
  #   (e.g., file directory, connection to a backend)
  def configure(options)
    backend = options['backend']
    if options['backends'][backend]['fail_configure']
      raise('configure() catastrophic failure')
    end

    Puppet.debug("#{@name} simpkv plugin configured")
  end

  # @return unique identifier assigned to this plugin instance
  attr_reader :name

  # Deletes a `key` from the configured backend.
  #
  # @param key String key
  #
  # @return results Hash
  #   * :result - Boolean indicating whether operation succeeded
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def delete(_key)
    raise('delete catastrophic failure')
  end

  # Deletes a whole folder from the configured backend.
  #
  # @param keydir String key folder path
  #
  # @return results Hash
  #   * :result - Boolean indicating whether operation succeeded
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def deletetree(_keydir)
    raise('deletetree catastrophic failure')
  end

  # Returns whether the `key` exists in the configured backend.
  #
  # @param key String key
  #
  # @return results Hash
  #   * :result - Boolean indicating whether key exists; nil if could not
  #     be determined
  #   * :err_msg - String. Explanatory text when status could not be
  #     determined; nil otherwise.
  #
  def exists(_key)
    raise('exists catastrophic failure')
  end

  # Retrieves the value stored at `key` from the configured backend.
  #
  # @param key String key
  #
  # @return results Hash
  #   * :result - String. Retrieved value for the key; nil if could not
  #     be retrieved
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def get(_key)
    raise('get catastrophic failure')
  end

  # Returns a list of all keys/value pairs in a folder
  #
  # This implementation is best effort.  It will attempt to retrieve the
  # information in a folder and only fail if the folder itself cannot be
  # accessed.  Individual key retrieval failures will be ignored.
  #
  # @return results Hash
  #   * :result - Hash of retrieved key/value pairs; nil if the
  #     retrieval operation failed
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def list(_keydir)
    raise('list catastrophic failure')
  end

  # Sets the data at `key` to a `value` in the configured backend.
  #
  # @param key String key
  # @param value String value
  #
  # @return results Hash
  #   * :result - Boolean indicating whether operation succeeded
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def put(_key, _value)
    raise('put catastrophic failure')
  end
end
