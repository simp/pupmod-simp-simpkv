# vim: set expandtab ts=2 sw=2:
def libkv()
  @libkv
end
def libkv=(value)
  @libkv = value
end

# Libkv global wrapper. 
# it's job is to contain all libkv code
# and data for the lifetime of the catalog,
# and allow mappings of urls to object instances,
# and provider classes.
#
# This is anonymous to allow for code updating.

c = Class.new do
  def initialize()
    @classes = {}
    @urls = {}
    @errorlogs = {}
    @default_url = ""
  end
  attr_accessor :classes
  attr_accessor :urls
  attr_accessor :default_url
  attr_accessor :errorlogs
  
  def load(name, &block)
    klass = Class.new(&block)
    @classes[name] = klass
  end
  def parseurl(url)
      hash = {}
      colonsplit = url.split(":");
      hash['provider'] = colonsplit[0].split("+")[0];
      return hash
  end
  def instancename(url, auth)
    if (auth == nil)
      auth_hash = ""
    else
      auth_hash = auth.hash
    end
    url + "@" + auth_hash.to_s
  end
  def pop_error(url, auth, *args, &block)
    instance == instancename(url, auth)
    if (errorlogs.key?(instance))
      errorlogs[instance].pop()
    end
  end
  def method_missing(symbol, url, auth, *args, &block)
    instance = instancename(url, auth)
    if (urls[instance] == nil)
      urlspec = parseurl(url)
      provider = urlspec['provider']
      urls[instance] = classes[provider].new(url, auth)
      errorlogs[instance] = [] 
    end
    object = urls[instance];
    object.send(symbol, *args, &block);
  end

end

# Use the adapter pattern to inject an anonymous
# module into the catalog, so we get a libkv
# attribute, and then assign an anonymous class
# to libkv. 
#
# Basically, there is no constants assigned to any
# libkv code, so there is no risk of environment or catalog
# poisoning if the underlying module is updated.

self.libkv = c.new()
libkv = self.libkv

# Every file in lib/puppet_x/libkv/*_provider.rb is assumed
# to contain a libkv backend provider, and we load them in.
#
# Every provider uses $LIBKV.load() to actually define itself,
# which results in catalog.libkv.classes['providername'] to return
# the Class that implements the provider.
providerglob = File.dirname(File.dirname(File.dirname(File.dirname(File.dirname(__FILE__))))) + "/*/lib/puppet_x/libkv/*_provider.rb"
Dir.glob(providerglob) do |filename|
  self.instance_eval File.read(filename), filename
end
