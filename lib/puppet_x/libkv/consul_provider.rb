# vim: set expandtab ts=2 sw=2:
require 'net/http'
require 'uri'
libkv.load("consul") do
  def initialize(url, auth)
    @uri = URI.parse(url)
    @resturi = URI.parse(url)
    case @uri.scheme
    when "consul"
      @resturi.scheme = "http"
    when "consul+ssl"
      @resturi.scheme = "https"
    end
    @basepath = @uri.path.chomp("/")
    # XXX: Todo: break out the rest client into a mixin
    #
    #    self.extend($LIBKV.restclient);
    #

  end

  # Begin REST Client

  def rest_request(params = {})
    unless params.key?(:method)
      params[:method] = 'GET'
    end
    http = Net::HTTP.new(@uri.host, @uri.port)
    case params[:method]
    when 'GET'
      request = Net::HTTP::Get.new(params[:path])
    when 'DELETE'
      request = Net::HTTP::Delete.new(params[:path])
    when 'PUT'
      request = Net::HTTP::Put.new(params[:path])
      request.body = params[:body]
    end
    response = http.request(request)
  end

  # End REST Client
  def consul_request(params)
    rest_request(params)
  end
  def supports(params)
    [
      "delete",
      "deletetree",
      'get',
      'put',
      'exists',
      'list',

      'atomic_create',
      'atomic_delete',
      'atomic_get',
      'atomic_put',
      'atomic_list',

      'empty_value',
      'info',
      'provider',
      'supports',
    ]
  end
  def provider(params)
    "consul"
  end
  def get(params)
    key = params['key']
    if (key == nil)
      throw Exception
    end
    begin
      response = consul_request(path: "/v1/kv" + @basepath + key)
      if (response.class == Net::HTTPOK)
        json = response.body
        parsed = JSON.parse(json)[0];
        value = Base64.decode64(parsed['Value']);
      elsif (response.class == Net::HTTPNotFound)
        self.empty_value({})['value']
      else
      end
    rescue
      nil
    end
  end

  def put(params)
    retval = {}
    debug = params['debug']
    key = params['key']
    value = params['value']

    if (key == nil)
      throw Exception
    end

    if (value == nil)
      throw Exception
    end
    response = consul_request(path: "/v1/kv" + @basepath + key, method: 'PUT', body: value)
    if (debug == true)
      retval["response_class"] = response.class
      retval["response_body"] = response.body
    end
    if (response.class == Net::HTTPOK)
      if (response.body == "true\n")
        retval["result"] = true
      else
        retval["result"] = false
      end
    else
      retval["result"] = false
    end
    unless (params["debug"] == true)
      retval = retval["result"]
    end
    return retval
  end

  def atomic_get(params)
    key = params['key']
    if (key == nil)
      throw Exception
    end
    begin
      response = consul_request(path: "/v1/kv" + @basepath + key)
      if (response.class == Net::HTTPOK)
        json = response.body
        parsed = JSON.parse(json)[0];
        parsed['value'] = Base64.decode64(parsed['Value']);
        parsed
      elsif (response.class == Net::HTTPNotFound)
        self.empty_value({})
      else
        throw Exception
      end
    rescue
      throw Exception
    end
  end

  def atomic_put(params)
    key = params['key']
    value = params['value']
    previous = params['previous']

    if (key == nil)
      throw Exception
    end

    if (value == nil)
      throw Exception
    end
    if (previous == nil)
      throw Exception
    end
    previndex=previous["ModifyIndex"]
    response = consul_request(path: "/v1/kv" + @basepath + key + "?cas=" + previndex.to_s, method: 'PUT', body: value)
    if (response.class == Net::HTTPOK)
      if (response.body == "true\n")
        true
      else
        false
      end
    elsif(response.class == Net::HTTPInternalServerError)
      false
    else
      false
    end
  end
  def atomic_delete(params)
    key = params['key']
    previous = params['previous']

    if (key == nil)
      throw Exception
    end
    if (previous == nil)
      throw Exception
    end
    previndex=previous["ModifyIndex"]
    response = consul_request(path: "/v1/kv" + @basepath + key + "?cas=" + previndex.to_s, method: 'DELETE')
    if (response.class == Net::HTTPOK)
      if (response.body == "true\n")
        true
      else
        false
      end
    else
      false
    end
  end
  def delete(params)
    key = params['key']
    if (key == nil)
      throw Exception
    end
    # Get the value of key first. This is the only way to tell if we try to delete a key 
    response = consul_request(path: "/v1/kv" + @basepath + key, method: 'DELETE')
    if (response.class == Net::HTTPOK)
      if (response.body == "true\n")
        true
      else
        false
      end
    else
      false
    end
  end
  def deletetree(params)
  end
  def info(params)
  end
  def atomic_list(params)
    key = params['key']
    last_char = key.slice(key.size - 1,1)
    if (last_char != "/")
      key = key + "/"
    end
    if (key == nil)
      throw Exception
    end
    begin
      response = consul_request(path: "/v1/kv" + @basepath + key + "?recurse")
      if (response.class == Net::HTTPOK)
        json = response.body
        value = JSON.parse(json)
      else
        nil
      end
    rescue
      nil
    end
  end
  def list(params)
    list = atomic_list(params)
    retval = {}
    key = params['key']
    last_char = key.slice(key.size - 1,1)
    if (last_char != "/")
      key = key + "/"
    end
    reg = Regexp.new("^" + @basepath.gsub(/\//, "") + key)

    unless (list == nil)
      list.each do |entry|
        nkey = entry["Key"].gsub(reg,"")
        retval[nkey] = Base64.decode64(entry["Value"])
      end
    end
    retval
  end
  def exists(params)
    key = params['key']
    if (key == nil)
      throw Exception
    end
    # Get the value of key first. This is the only way to tell if we try to delete a key 
    response = consul_request(path: "/v1/kv" + @basepath + key + "?keys", method: 'GET')
    if (response.class == Net::HTTPOK)
      true
    elsif(response.class == Net::HTTPNotFound)
      false
    else
      false
    end

  end
  def empty_value(params)
    {
      "ModifyIndex" => 0,
      "value" => nil
    }
  end
end
