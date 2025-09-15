require 'spec_helper'

describe 'simpkv::support::config::validate' do
  let(:backends) { [ 'file' ] }

  context 'valid backend config' do
    it 'allows valid config' do
      config = {
        'backend'     => 'test_file',
        'environment' => 'production',
        'backends'    => {
          'test_file' => {
            'id'        => 'test',
            'type'      => 'file'
          },
          # this duplicate is OK because its config exactly matches test_file
          'test_file_dup' => {
            'id'        => 'test',
            'type'      => 'file'
          },
          'another_file' => {
            'id'        => 'another_test',
            'type'      => 'file'
          },
          'consul_1' => {
            'id'        => 'primary',
            'type'      => 'consul'
          },
          'consul_2' => {
            'id'        => 'secondary',
            'type'      => 'consul'
          }
        }
      }

      is_expected.to run.with_params(config, backends)
    end
  end

  context 'invalid backend config' do
    it "fails when options is missing 'backend'" do
      options = {}
      is_expected.to run.with_params(options, backends)
                        .and_raise_error(ArgumentError,
        %r{'backend' not specified in simpkv configuration})
    end

    it "fails when options is missing 'backends'" do
      options = { 'backend' => 'file' }
      is_expected.to run.with_params(options, backends)
                        .and_raise_error(ArgumentError,
        %r{'backends' not specified in simpkv configuration})
    end

    it "fails when 'backends' in not a Hash" do
      options = { 'backend' => 'file', 'backends' => [] }
      is_expected.to run.with_params(options, backends)
                        .and_raise_error(ArgumentError,
        %r{'backends' in simpkv configuration is not a Hash})
    end

    it "fails when 'backends' does not have an entry for 'backend'" do
      options = { 'backend' => 'file', 'backends' => {} }
      is_expected.to run.with_params(options, backends)
                        .and_raise_error(ArgumentError,
        %r{No simpkv backend 'file' with 'id' and 'type' attributes has been configured})
    end

    it "fails when 'backends' entry for 'backend' is not a Hash" do
      options = { 'backend' => 'file', 'backends' => { 'file' => [] } }
      is_expected.to run.with_params(options, backends)
                        .and_raise_error(ArgumentError,
        %r{No simpkv backend 'file' with 'id' and 'type' attributes has been configured})
    end

    it "fails when 'backends' entry for 'backend' is missing 'id'" do
      options = { 'backend' => 'file', 'backends' => { 'file' => {} } }
      is_expected.to run.with_params(options, backends)
                        .and_raise_error(ArgumentError,
        %r{No simpkv backend 'file' with 'id' and 'type' attributes has been configured})
    end

    it "fails when 'backends' entry for 'backend' is missing 'type'" do
      options = { 'backend' => 'file', 'backends' => { 'file' => { 'id' => 'test' } } }
      is_expected.to run.with_params(options, backends)
                        .and_raise_error(ArgumentError,
        %r{No simpkv backend 'file' with 'id' and 'type' attributes has been configured})
    end

    it "fails when the plugin for 'backend' has not been loaded" do
      options = {
        'backend'  => 'file',
        'backends' => { 'file' => { 'id' => 'test', 'type' => 'file' } }
      }
      is_expected.to run.with_params(options, [ 'consul' ])
                        .and_raise_error(ArgumentError,
        %r{simpkv backend plugin 'file' not available})
    end

    it "fails when 'backends' contains conflicting configs for the same plugin instance" do
      options = {
        'backend'  => 'file1',
        'backends' => {
          'file1'     => { 'id' => 'test', 'type' => 'file' },

          # this should have a different id because it has different config
          'file2'     => { 'id' => 'test', 'type' => 'file', 'foo' => 'bar' }
        }
      }
      is_expected.to run.with_params(options, backends)
                        .and_raise_error(ArgumentError,
        %r{simpkv config contains different backend configs for type=file id=test})
    end
  end
end
