# vim: set expandtab ts=2 sw=2:
require 'erb'
template = File.read('./template.erb');
renderer = ERB.new(template)

{

  "delete" => {
    :softfail => 'false'
  },
  "deletetree" => {
    :softfail => 'false',
  },
  "get" => {
    :softfail => 'nil',
  },
  "put" => {
    :softfail => 'false',
  },
  "exists" => {
    :softfail => 'nil',
  },
  "list" => {
    :softfail => '{}',
  },


  "atomic_create" => {
    :softfail => '{}',
  },
  "atomic_delete" => {
    :softfail => '{}',
  },
  "atomic_get" => {
    :softfail => '{}',
  },
  "atomic_put" => {
    :softfail => '{}',
  },
  "atomic_list" => {
    :softfail => '{}',
  },


  "empty_value" => {
    :softfail => 'nil',
  },
  "info" => {
    :softfail => '{}'
  },
  "supports" => {
    :softfail => '[]',
    :allow_empty => true,
  },
  "provider" => {
    :softfail => '""',
    :allow_empty => true,
  },


  "watch" => {},
  "watchtree" => {},
  "newlock" => {},

}.each do |function, value|
  b = binding;
  b.local_variable_set(:function, function);
  b.local_variable_set(:value, value);
  result = renderer.result(b);
  File.write("../lib/puppet/functions/libkv/#{function}.rb", result)
end
