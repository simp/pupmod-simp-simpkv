# Load simpkv adapter and plugins and add simpkv 'extension' to the catalog
# instance, if it is not present
#
# @author https://github.com/simp/pupmod-simp-simpkv/graphs/contributors
#
Puppet::Functions.create_function(:'simpkv::support::load') do

  # @return [Nil]
  # @raise LoadError if simpkv adapter software fails to load
  #
  dispatch :load do
  end

  def load
    catalog = closure_scope.find_global_scope.catalog
    unless catalog.respond_to?(:simpkv)
      # load and instantiate simpkv adapter and then add it as a
      # 'simpkv' attribute to the catalog instance
      lib_dir = File.dirname(File.dirname(File.dirname(File.dirname(File.dirname("#{__FILE__}")))))
      filename = File.join(lib_dir, 'puppet_x', 'simpkv', 'loader.rb')
      if File.exist?(filename)
        begin
          catalog.instance_eval(File.read(filename), filename)
        rescue SyntaxError => e
          raise(LoadError,
            "simpkv Internal Error: unable to load #{filename}: #{e.message}"
          )
        end
      else
        raise(LoadError,
          "simpkv Internal Error: unable to load #{filename}: File not found"
        )
      end
    end
  end

end
