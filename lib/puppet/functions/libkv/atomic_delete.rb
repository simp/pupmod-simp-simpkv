# Delete `key`, but only if key still matches the value of `previous`
#
# @author https://github.com/simp/pupmod-simp-libkv/graphs/contributors
#
Puppet::Functions.create_function(:'libkv::atomic_delete') do

  # @param parameters [Hash] Hash of all parameters
  #
  # @return [Boolean] Whether the backend delete operation succeeded
  #
  dispatch :atomic_delete do
    param 'Hash', :parameters
  end

  # @param key The key to delete
  # @param previous The value in the underlying backing store
  #
  # @return [Boolean] Whether the backend delete operation succeeded
  #
  dispatch :atomic_delete_v1 do
    param 'String', :key
    param 'Hash', :previous
  end

  def atomic_delete_v1(key, previous)
    params = {}
    params['key'] = key
    params['previous'] = previous

    atomic_delete(params)
  end

  def atomic_delete(params)
    nparams = params.dup
    if (closure_scope.class.to_s == 'Puppet::Parser::Scope')
      catalog = closure_scope.find_global_scope.catalog
    else
      if ($__LIBKV_CATALOG == nil)
        catalog = Object.new
        $__LIBKV_CATALOG = catalog
      else
        catalog = $__LIBKV_CATALOG
      end
    end
    begin
      find_libkv = catalog.libkv
    rescue
      filename = File.dirname(File.dirname(File.dirname(File.dirname("#{__FILE__}")))) + "/puppet_x/libkv/loader.rb"
      if File.exists?(filename)
        catalog.instance_eval(File.read(filename), filename)
        find_libkv = catalog.libkv
      else
        raise Exception
      end
    end
    libkv = find_libkv
    if nparams.key?('url')
      url = nparams['url']
    else
      url = call_function('lookup', 'libkv::url', { 'default_value' => 'mock://'})
    end
    nparams["url"] = url

    if nparams.key?('auth')
      auth = nparams['auth']
    else
      auth = call_function('lookup', 'libkv::auth', { 'default_value' => nil })
    end
    nparams["auth"] = auth
    if (nparams["softfail"] == true)
      begin
        retval = libkv.atomic_delete(url, auth, nparams);
      rescue
        retval = {}
      end
    else
      retval = libkv.atomic_delete(url, auth, nparams);
    end
    return retval;
  end
end

# vim: set expandtab ts=2 sw=2:
