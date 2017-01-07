# vim: set expandtab ts=2 sw=2:
#
# @author Dylan Cochran <dylan.cochran@onyxpoint.com>
Puppet::Functions.create_function(:'libkv::watchtree') do
  # @param parameters [Hash] Hash of all parameters
  # 
  # @param key [String] string of the key to retrieve
  #
  # @return [Any] The value in the underlying backing store
  #
  #
  dispatch :watchtree do
    param 'Hash', :parameters
  end


def watchtree(params)
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
    if params.key?('key')
      regex = Regexp.new('^\/[a-zA-Z0-9._\-\/]+$')
      unless (regex =~ params['key'])
       if (params["softfail"] == true)
         retval = 
         return retval
       else
       raise "the specified key, '#{params['key']}' does not match regex '#{regex}'"
       end
      end
    end
    if (params["softfail"] == true)
      begin
        retval = libkv.watchtree(url, params);
      rescue
        retval = 
      end
    else
      retval = libkv.watchtree(url, params);
    end
    return retval;
  end
end

