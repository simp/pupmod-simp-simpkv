# Returns a listing of all keys and sub-folders in a folder.
#
# The list operation does not recurse through any sub-folders. Only information
# about the specified key folder is returned.
#
# @author https://github.com/simp/pupmod-simp-simpkv/graphs/contributors
#
Puppet::Functions.create_function(:'simpkv::list') do
  # @param keydir The key folder to list. Must conform to the following:
  #
  #   * Key folder must contain only the following characters:
  #
  #     * a-z
  #     * 0-9
  #     * The following special characters: `._:-/`
  #
  #   * Key folder may not contain '/./' or '/../' sequences.
  #
  # @param options simpkv configuration that will be merged with
  #   `simpkv::options`.  All keys are optional.
  #
  # @option options [String] 'app_id'
  #   Specifies an application name that can be used to identify which backend
  #   configuration to use via fuzzy name matching, in the absence of the
  #   `backend` option.
  #
  #     * More flexible option than `backend`.
  #     * Useful for grouping together simpkv function calls found in different
  #       catalog resources.
  #     * When specified and the `backend` option is absent, the backend will be
  #       selected preferring a backend in the merged `backends` option whose
  #       name exactly matches the `app_id`, followed by the longest backend
  #       name that matches the beginning of the `app_id`, followed by the
  #       `default` backend.
  #     * When absent and the `backend` option is also absent, this function
  #       will use the `default` backend.
  #
  # @option options [String] 'backend'
  #   Definitive name of the backend to use.
  #
  #     * Takes precedence over `app_id`.
  #     * When present, must match a key in the `backends` option of the
  #       merged options Hash or the function will fail.
  #     * When absent in the merged options, this function will select
  #       the backend as described in the `app_id` option.
  #
  # @option options [Hash] 'backends'
  #   Hash of backend configurations
  #
  #     * Each backend configuration in the merged options Hash must be
  #       a Hash that has the following keys:
  #
  #       * `type`:  Backend type.
  #       * `id`:  Unique name for the instance of the backend. (Same backend
  #         type can be configured differently).
  #
  #      * Other keys for configuration specific to the backend may also be
  #        present.
  #
  # @option options [Boolean] 'global'
  #   Set to `true` when the key being accessed is global. Otherwise, the key
  #   will be tied to the Puppet environment of the node whose manifest is
  #   being compiled.
  #
  #     * Defaults to `false`
  #
  # @option options [Boolean] 'softfail'
  #   Whether to ignore simpkv operation failures.
  #
  #     * When `true`, this function will return a result even when the
  #       operation failed at the backend.
  #     * When `false`, this function will fail when the backend operation
  #       failed.
  #     * Defaults to `false`.
  #
  # @raise ArgumentError If the key folder or merged backend config is invalid
  #
  # @raise LoadError If the simpkv adapter cannot be loaded
  #
  # @raise RuntimeError If the backend operation fails, unless 'softfail' is
  #   `true` in the merged backend options.
  #
  # @return [Enum[Hash,Undef]] Hash containing the key/info pairs and list of
  #   sub-folders upon success; Undef when the backend operation fails and
  #   'softfail' is `true` in the merged backend options
  #
  #   * 'keys' attribute is a Hash of the key information in the folder
  #     * Each Hash key is a key found in the folder
  #     * Each Hash value is a Hash with a 'value' key and an optional
  #       'metadata' key.
  #   * 'folders' attribute is an Array of sub-folder names
  #
  # @example Retrieve the list of key info for a key folder from the default backend
  #   $result = simpkv::list('hosts')
  #   $result['keys'].each |$host, $info | {
  #     host { $host:
  #       ip => $info['value'],
  #     }
  #   }
  #
  # @example Retrieve the list of sub-folders in a key folder from the backend servicing an application id
  #   $result = simpkv::list('applications', { 'app_id' => 'myapp' })
  #   notice("Supported applications: ${join($result['folders'], ' ')}")
  #
  # @example Retrieve the top level list of global keys/folders in the default backend
  #   $result = simpkv::list('/', { 'global' = true })
  #   notice("Global folders: ${join($result['folders'], ' ')}")
  #   $result['keys'].each |$key, $info | {
  #     notice("Global key ${key}: value=${info['value']} metadata=${info['metadata']}")
  #   }
  #
  dispatch :list do
    required_param 'String[1]', :keydir
    optional_param 'Hash',      :options
  end

  def list(keydir, options = {})
    # keydir validation difficult to do via a type alias, so validate via function
    call_function('simpkv::support::key::validate', keydir)

    # load simpkv and add simpkv 'extension' to the catalog instance as needed
    call_function('simpkv::support::load')

    # determine backend configuration using options, `simpkv::options`,
    # and the list of backends for which plugins have been loaded
    begin
      catalog = closure_scope.find_global_scope.catalog
      merged_options = call_function('simpkv::support::config::merge', options,
        catalog.simpkv.backends)
    rescue ArgumentError => e
      msg = "simpkv Configuration Error for simpkv::list with keydir='#{keydir}': #{e.message}"
      raise ArgumentError, msg
    end

    # use simpkv for list operation
    backend_result = catalog.simpkv.list(keydir, merged_options)

    result = backend_result[:result]
    if result.nil?
      err_msg = "simpkv Error for simpkv::list with keydir='#{keydir}': #{backend_result[:err_msg]}"
      raise(err_msg) unless merged_options['softfail']
      Puppet.warning(err_msg)

    else
      result = { 'keys' => {}, 'folders' => backend_result[:result][:folders] }
      backend_result[:result][:keys].each do |key, info|
        result['keys'][key] = { 'value' => info[:value] }
        unless info[:metadata].empty?
          result['keys'][key]['metadata'] = info[:metadata]
        end
      end
    end

    result
  end
end
