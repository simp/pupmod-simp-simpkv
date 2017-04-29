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
    @default_url = ""
  end
  attr_accessor :classes
  attr_accessor :urls
  attr_accessor :default_url
  
  def load(name, &block)
    @classes[name] = Class.new(&block)
  end
  def parseurl(url)
      hash = {}
      colonsplit = url.split(":");
      hash['provider'] = colonsplit[0].split("+")[0];
      return hash
  end
  def method_missing(symbol, url, auth, *args, &block)
    params = args[0]
    unless (params.key?("serialize"))
      params["serialize"] = false
    end
    unless (params.key?("mode"))
      params["mode"] = 'puppet'
    end
    if (auth == nil)
      auth_hash = ""
    else
      auth_hash = auth.hash
    end
    instance = url + "@" + auth_hash.to_s
    if (urls[instance] == nil)
      urlspec = parseurl(url)
      provider = urlspec['provider']
      urls[instance] = classes[provider].new(url, auth)
    end
    object = urls[instance];
    case symbol
    when :put
      meta = []
      meta[0] = Hash.new(params)
      meta[0]["key"] = "#{params['key']}.meta"
      nvalue = {}
      nvalue["type"] = puppetype(params["value"])
      nvalue["format"] = "json"
      nvalue["mode"] = "puppet"
      meta[0]["value"] = nvalue.to_json
      object.send(:put, *meta, &block);
    when :atomic_put
      meta = []
      meta[0] = Hash.new(params)
      meta[0]["key"] = "#{params['key']}.meta"
      nvalue = {}
      nvalue["type"] = puppetype(params["value"])
      nvalue["format"] = "json"
      nvalue["mode"] = "puppet"
      meta[0]["value"] = nvalue.to_json
      object.send(:put, *meta, &block);
    end
    retval = object.send(symbol, *args, &block);
    case symbol
    when :list
	filtered_list = {}
	retval.each do |entry, value|
          unless (entry =~ /.*\.meta$/)
            filtered_list[entry] = value
          end
	end
        return filtered_list
    when :atomic_list
	filtered_list = {}
	retval.each do |entry, value|
          unless (entry =~ /.*\.meta$/)
            filtered_list[entry] = value
          end
	end
        return filtered_list
    else
       return retval
    end
  end
  def puppetype(klass)
    retval = nil
    case klass.class.to_s
    when "Fixnum"
      retval = "Integer"
    when "Float"
      retval = "Float"
    when "Array"
      retval = "Array"
    when "Hash"
      retval = "Hash"
    when "TrueClass"
      retval = "Boolean"
    when "FalseClass"
      retval = "Boolean"
    end
    retval
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
