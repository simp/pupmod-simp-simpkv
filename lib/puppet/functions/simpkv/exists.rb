# Returns whether key or key folder exists in the configured backend.
#
# @author https://github.com/simp/pupmod-simp-simpkv/graphs/contributors
#
Puppet::Functions.create_function(:'simpkv::exists') do
  # @param key The key or key folder to check. Must conform to the following:
  #
  #   * Key must contain only the following characters:
  #
  #     * a-z
  #     * 0-9
  #     * The following special characters: `._:-/`
  #
  #   * Key may not contain '/./' or '/../' sequences.
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
  # @raise ArgumentError If the key or merged backend config is invalid
  #
  # @raise LoadError If the simpkv adapter cannot be loaded
  #
  # @raise RuntimeError If the backend operation fails, unless 'softfail' is
  #   `true` in the merged backend options.
  #
  # @return [Enum[Boolean,Undef]] If the backend operation succeeds, returns
  #   `true` or `false`; if the backend operation fails and 'softfail' is `true`
  #   in the merged backend options, returns nil
  #
  # @example Check for the existence of a key in the default backend
  #   if simpkv::exists("hosts/${facts['fqdn']}") {
  #      notify { "hosts/${facts['fqdn']} exists": }
  #   }
  #
  # @example Check for the existence of a key in the backend servicing an application id
  #   if simpkv::exists("hosts/${facts['fqdn']}", { 'app_id' => 'myapp' }) {
  #      notify { "hosts/${facts['fqdn']} exists": }
  #   }
  #
  # @example Check for the existence of a global key folder in the default backend
  #   if simpkv::exists("hosts", { 'global' => true}) {
  #      notify { 'hosts folder exists': }
  #   }
  #
  dispatch :exists do
    required_param 'String[1]', :key
    optional_param 'Hash',      :options
  end

  def exists(key, options = {})
    # key validation difficult to do via a type alias, so validate via function
    call_function('simpkv::support::key::validate', key)

    # load simpkv and add simpkv 'extension' to the catalog instance as needed
    call_function('simpkv::support::load')

    # determine backend configuration using options, `simpkv::options`,
    # and the list of backends for which plugins have been loaded
    begin
      catalog = closure_scope.find_global_scope.catalog
      merged_options = call_function('simpkv::support::config::merge', options,
        catalog.simpkv.backends)
    rescue ArgumentError => e
      msg = "simpkv Configuration Error for simpkv::exists with key='#{key}': #{e.message}"
      raise ArgumentError, msg
    end

    # use simpkv for exists operation
    backend_result = catalog.simpkv.exists(key, merged_options)
    success = backend_result[:result]
    if success.nil?
      err_msg = "simpkv Error for simpkv::exists with key='#{key}': #{backend_result[:err_msg]}"
      raise(err_msg) unless merged_options['softfail']
      Puppet.warning(err_msg)

    end

    success
  end
end
