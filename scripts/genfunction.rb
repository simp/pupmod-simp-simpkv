# vim: set expandtab ts=2 sw=2:
require 'erb'
template = File.read('./template.erb');
renderer = ERB.new(template)
require 'yaml'
data = YAML.load_file('data.yaml')

data.each do |function, value|
  b = binding;
  b.local_variable_set(:function, function);
  b.local_variable_set(:value, value);
  result = renderer.result(b);
  File.write("../lib/puppet/functions/libkv/#{function}.rb", result)
end
