# Deletes a whole folder from the configured backend.
#
# @author https://github.com/simp/pupmod-simp-simpkv/graphs/contributors
#
Puppet::Functions.create_function(:'simpkv::deletetree') do

  # @param keydir The key folder to remove. Must conform to the following:
  #
  #   * Key folder must contain only the following characters:
  #
  #     * a-z
  #     * A-Z
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
  # @option options [String] 'environment'
  #   Puppet environment to prepend to keys.
  #
  #     * When set to a non-empty string, it is prepended to the key used in
  #       the backend operation.
  #     * Should only be set to an empty string when the key being accessed is
  #       truly global.
  #     * Defaults to the Puppet environment for the node.
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
  # @return [Boolean] `true` when backend operation succeeds; `false` when the
  #   backend operation fails and 'softfail' is `true` in the merged backend
  #   options
  #
  # @example Delete a key folder using the default backend
  #   simpkv::deletetree("hosts")
  #
  # @example Delete a key folder using the backend servicing an appliction id
  #   simpkv::deletetree("hosts", { 'app_id' => 'myapp' })
  #
  dispatch :deletetree do
    required_param 'String[1]', :keydir
    optional_param 'Hash',      :options
  end

  def deletetree(keydir, options={})
    # keydir validation difficult to do via a type alias, so validate via function
    call_function('simpkv::support::key::validate', keydir)

    # load simpkv and add simpkv 'extension' to the catalog instance as needed
    call_function('simpkv::support::load')

    # determine backend configuration using options, `simpkv::options`,
    # and the list of backends for which plugins have been loaded
    begin
      catalog = closure_scope.find_global_scope.catalog
      merged_options = call_function( 'simpkv::support::config::merge', options,
        catalog.simpkv.backends)
    rescue ArgumentError => e
      msg = "simpkv Configuration Error for simpkv::deletetree with keydir='#{keydir}': #{e.message}"
      raise ArgumentError.new(msg)
    end

    # use simpkv for delete operation
    backend_result = catalog.simpkv.deletetree(keydir, merged_options)
    success = backend_result[:result]
    unless success
      err_msg =  "simpkv Error for simpkv::deletetree with keydir='#{keydir}': #{backend_result[:err_msg]}"
      if merged_options['softfail']
        Puppet.warning(err_msg)
      else
        raise(err_msg)
      end
    end

    success
  end
end
