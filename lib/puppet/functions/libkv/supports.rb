# vim: set expandtab ts=2 sw=2:
#
# @author Dylan Cochran <dylan.cochran@onyxpoint.com>
Puppet::Functions.create_function(:'libkv::supports') do
  # @param parameters [Hash] Hash of all parameters
  # 
  # @param key [String] string of the key to retrieve
  #
  # @return [Any] The value in the underlying backing store
  #
  #
  dispatch :supports do
    param 'Hash', :parameters
  end


  dispatch :supports_empty do
  end
  def supports_empty
     self.supports({})
  end


def supports(params)
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
    if params.key?('url')
      url = params['url']
    else
      url = call_function('lookup', 'libkv::url', { 'default_value' => 'mock://'})
    end
    params["url"] = url
    if params.key?('softfail')
      softfail = params['softfail']
    else
      softfail = call_function('lookup', 'libkv::softfail', { 'default_value' => false})
    end
    params["softfail"] = softfail 
    if params.key?('auth')
      auth = params['auth']
    else
      auth = call_function('lookup', 'libkv::auth', { 'default_value' => nil })
    end
    params["auth"] = auth
    if params.key?('key')
      regex = Regexp.new('^\/[a-zA-Z0-9._\-\/]+$')
      error_msg = "the specified key, '#{params['key']}' does not match regex '#{regex}'"
      unless (regex =~ params['key'])
       if (params["softfail"] == true)
         retval = []
         Puppet.warning(error_msg)
         return retval
       else
       raise error_msg
       end
      end
    end
    if (params["softfail"] == true)
      begin
        retval = libkv.supports(url, auth, params);
      rescue Exception => e
        Puppet.warning(e.message)
        retval = []
      end
    else
      retval = libkv.supports(url, auth, params);
    end
    return retval;
  end
end

