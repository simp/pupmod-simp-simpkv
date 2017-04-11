# vim: set expandtab ts=2 sw=2:
#
# @author Dylan Cochran <dylan.cochran@onyxpoint.com>
Puppet::Functions.create_function(:'libkv::empty_value') do
  # @param parameters [Hash] Hash of all parameters
  # 
  # @param key [String] string of the key to retrieve
  #
  # @return [Any] The value in the underlying backing store
  #
  #
  dispatch :empty_value do
    param 'Hash', :parameters
  end


  dispatch :empty_value_empty do
  end
  def empty_value_empty
     self.empty_value({})
  end


def empty_value(params)
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
    if params.key?('auth')
      auth = params['auth']
    else
      auth = call_function('lookup', 'libkv::auth', { 'default_value' => nil })
    end
    if params.key?('key')
      regex = Regexp.new('^\/[a-zA-Z0-9._\-\/]+$')
      unless (regex =~ params['key'])
       if (params["softfail"] == true)
         retval = nil
         return retval
       else
       raise "the specified key, '#{params['key']}' does not match regex '#{regex}'"
       end
      end
    end
    if (params["softfail"] == true)
      begin
        retval = libkv.empty_value(url, auth, params);
      rescue
        warn_once("test")
        retval = nil
      end
    else
      retval = libkv.empty_value(url, auth, params);
    end
    return retval;
  end
end

