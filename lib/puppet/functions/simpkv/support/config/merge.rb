# Create merged backend configuration and then validate it.
#
# The merge entails the following operations:
# * The `options` argument is merged with `simpkv::options` Hiera and global
#   simpkv defaults.
#
# * If the `backend` options is missing in the merged options, it is set to
#   a value determined as follows:
#
#   * If the `app_id` option is present and the name of a backend in `backends`
#     matches `app_id`, `backend` will be set to `app_id`.
#   * Otherwise, if the `app_id` option is present and the name of a backend in
#     `backends` matches the beginning of `app_id`, `backend` will be set to
#     that partially-matching backend name. When multiple backends satisfy
#     the 'start with' match, the backend with the most matching characters is
#     selected.
#   * Otherwise, if the `app_id` option does not match any backend name or is
#     not present, `backend` will be set to `default`.
#
# * If the `backends` option is missing in the merged options, it is set to
#   a Hash containing a single entry, `default`, that has configuration for
#   the simpkv 'file' backend.
#
# Validation includes the following checks:
# * configuration for the selected backend exists
# * the plugin for the selected backend has been loaded
# * different configuration for a specific plugin instance does not exist
#
# @author https://github.com/simp/pupmod-simp-simpkv/graphs/contributors
#
Puppet::Functions.create_function(:'simpkv::support::config::merge') do

  # @param options Hash that specifies simpkv backend options to be merged with
  #   `simpkv::options`.
  #
  # @param backends List of backends for which plugins have been successfully
  #   loaded.
  #
  # @return [Hash] merged simpkv options that will have the backend to use
  #   specified by 'backend'
  #
  # @raise ArgumentError if merged configuration fails validation
  #
  # @see simpkv::support::config::validate
  #
  dispatch :merge do
    param 'Hash',      :options
    param 'Array',     :backends
  end

  def merge(options, backends)
    merged_options = merge_options(options)
    call_function('simpkv::support::config::validate', merged_options, backends)
    return merged_options
  end

  # merge options; set defaults for 'backend', 'environment', 'global' and
  # 'softfail' when missing; and when 'backends' is missing, insert a 'default'
  # backend of type 'file'.
  #
  # 'environment' is an internal option required by the simpkv adapter. It
  # is used to generate the environment-specific prefix to the key path.
  def merge_options(options)
    require 'deep_merge'
    # deep_merge will not work with frozen options, so make a deep copy
    # (options.dup is a shallow copy of contained Hashes)
    options_dup = Marshal.load(Marshal.dump(options))
    app_id = options.has_key?('app_id') ? options['app_id'] : 'default'

    merged_options = call_function('lookup', 'simpkv::options', { 'default_value' => {} })
    merged_options.deep_merge!(options_dup)

    backend_names = [ 'default' ]
    if merged_options.has_key?('backends')
      # reverse sort by length of string so we get the longest match when using
      # a partial match
      backend_names = merged_options['backends'].keys.sort_by(&:length).reverse
    else
      Puppet.debug("simpkv: No backends configured. 'file' backend automatically added")
      merged_options['backends'] = {
        'default' => {
          'type' => 'file',
          'id'   => 'auto_default'
        }
      }
    end

    unless merged_options.has_key?('backend')
      backend = 'default'
      if backend_names.include?(app_id)
        backend = app_id
      else
        backend_names.each do |name|
          if app_id.start_with?(name)
            backend = name
            break
          end
        end
      end
      merged_options['backend'] = backend
    end

    unless merged_options.has_key?('softfail')
      merged_options['softfail'] = false
    end

    unless merged_options.has_key?('global')
      merged_options['global'] = false
    end

    merged_options['environment'] = closure_scope.compiler.environment.to_s

    merged_options
  end
end

