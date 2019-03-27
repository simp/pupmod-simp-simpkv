# Return the error message for the last call
#
# @author https://github.com/simp/pupmod-simp-libkv/graphs/contributors
#
Puppet::Functions.create_function(:'libkv::pop_error') do

  # @param parameters [Hash] Hash of all parameters
  #
  # @return [String] Provider's error message for the last call
  #
  dispatch :pop_error do
    param 'Hash', :parameters
  end

  # @return [String] Provider's error message for the last call
  #
  dispatch :pop_error_empty do
  end

  def pop_error_empty
     self.pop_error({})
  end

  def pop_error(params)
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
        retval = libkv.pop_error(url, auth, nparams);
      rescue
        retval = ""
      end
    else
      retval = libkv.pop_error(url, auth, nparams);
    end
    return retval;
  end
end

# vim: set expandtab ts=2 sw=2:
