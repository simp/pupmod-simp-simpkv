require 'spec_helper'

describe 'simpkv::support::config::merge' do
  let(:backends) { [ 'file' ] }

  # tell puppet-rspec to set Puppet environment to 'myenv'
  let(:environment) { 'myenv' }

  context 'simpkv::options and app_id not specified' do
    it "justs add 'environment' to merged config when all other config specified" do
      input_config = {
        'backend'     => 'default',
        'global'      => true,
        'softfail'    => true,
        'backends'    => {
          'default' => {
            'id'   => 'test',
            'type' => 'file'
          }
        }
      }
      output_config = input_config.dup
      output_config['environment'] = environment

      is_expected.to run.with_params(input_config, backends).and_return(output_config)
    end

    it "adds default 'backend' to merged config when missing" do
      input_config = {
        'global'      => false,
        'softfail'    => true,
        'backends'    => {
          'default' => {
            'id'   => 'test',
            'type' => 'file'
          }
        }
      }
      output_config = input_config.dup
      output_config['environment'] = environment
      output_config['backend'] = 'default'

      is_expected.to run.with_params(input_config, backends)
                        .and_return(output_config)
    end

    it "adds 'global' to merged config when missing" do
      input_config = {
        'backend'     => 'default',
        'softfail'    => true,
        'backends'    => {
          'default' => {
            'id'   => 'test',
            'type' => 'file'
          }
        }
      }
      output_config = input_config.dup
      output_config['environment'] = environment
      output_config['global'] = false

      is_expected.to run.with_params(input_config, backends)
                        .and_return(output_config)
    end

    it "adds 'softfail' to merged config when missing" do
      input_config = {
        'backend'     => 'default',
        'global'      => true,
        'backends'    => {
          'default' => {
            'id'   => 'test',
            'type' => 'file'
          }
        }
      }
      output_config = input_config.dup
      output_config['environment'] = environment
      output_config['softfail'] = false

      is_expected.to run.with_params(input_config, backends)
                        .and_return(output_config)
    end

    it "adds 'backends' with file backend auto-default when backends missing" do
      output_config = {
        'environment' => environment,
        'global'      => false,
        'softfail'    => false,
        'backend'     => 'default',
        'backends'    => {
          'default' => {
            'id'   => 'auto_default',
            'type' => 'file'
          }
        }
      }
      is_expected.to run.with_params({}, backends)
                        .and_return(output_config)
    end

    it 'fails when input config is invalid' do
      options = {
        'backends' => {
          'default' => {
            'id'   => 'test',
            'type' => 'does_not_exist'
          }
        }
      }
      is_expected.to run.with_params(options, backends)
                        .and_raise_error(ArgumentError,
        %r{simpkv backend plugin 'does_not_exist' not available})
    end
  end

  context 'simpkv::options specified' do
    let(:hieradata) { 'one_backend' }

    it 'returns simpkv::options config when no input config is specified' do
      output_config = {
        'backend'     => 'default',
        'environment' => environment,
        'global'      => false,
        'softfail'    => false,
        'backends'    => {
          'default' => {
            'type'                 => 'file',
            'id'                   => 'file',
            'root_path'            => '/var/simp/simpkv/file',
            'lock_timeout_seconds' => 30
          }
        }
      }

      is_expected.to run.with_params({}, backends)
                        .and_return(output_config)
    end

    it 'merges input config and simpkv::options but defer to input config' do
      input_config = {
        'backend'     => 'test',
        'global'      => true,
        'softfail'    => true,
        'backends'    => {
          'test' => {
            'type'      => 'file',
            'id'        => 'test',
            'root_path' => '/tmp/test',
          }
        }
      }

      output_config = {
        'backend'     => 'test',
        'environment' => environment,
        'global'      => true,
        'softfail'    => true,
        'backends'    => {
          'default' => {
            'type'                 => 'file',
            'id'                   => 'file',
            'root_path'            => '/var/simp/simpkv/file',
            'lock_timeout_seconds' => 30
          },
          'test' => {
            'type'      => 'file',
            'id'        => 'test',
            'root_path' => '/tmp/test',
          }
        }
      }
      is_expected.to run.with_params(input_config, backends)
                        .and_return(output_config)
    end

    it 'fails when merged config is invalid' do
      input_config = { 'backend' => 'test' }

      is_expected.to run.with_params(input_config, backends)
                        .and_raise_error(ArgumentError,
        %r{No simpkv backend 'test' with 'id' and 'type' attributes has been configured})
    end
  end

  context 'backend lookup using app_id' do
    let(:hieradata) { 'multiple_backends' }

    # alias expanded version of simpkv:options in multiple_backends.yaml with
    # environment added
    let(:simpkv_options) do
      {
        'environment' => environment,
      'global'      => false,
      'softfail'    => false,
      'backends'    => {
        'myapp1_special_snowflake' => {
          'type'                 => 'file',
          'id'                   => 'file',
          'root_path'            => '/var/simp/simpkv/file',
          'lock_timeout_seconds' => 30
        },
        'myapp1' => {
          'type'                 => 'file',
          'id'                   => 'file',
          'root_path'            => '/var/simp/simpkv/file',
          'lock_timeout_seconds' => 30
        },
        'myapp' => {
          'type'      => 'file',
          'id'        => 'alt_file',
          'root_path' => '/some/other/path'
        },
        'default' => {
          'type'                 => 'file',
          'id'                   => 'file',
          'root_path'            => '/var/simp/simpkv/file',
          'lock_timeout_seconds' => 30
        }
      }
      }
    end

    it "sets 'backend' to match 'app_id' when exact match exists" do
      expected = simpkv_options.dup
      expected['app_id'] = 'myapp1_special_snowflake'
      expected['backend'] = 'myapp1_special_snowflake'
      is_expected.to run.with_params({ 'app_id' => 'myapp1_special_snowflake' },
        backends).and_return(expected)
    end

    it "sets 'backend' to longest match of 'app_id' beginning when start with match exists" do
      expected = simpkv_options.dup
      expected['app_id'] = 'myapp10'
      expected['backend'] = 'myapp1'
      is_expected.to run.with_params({ 'app_id' => 'myapp10' }, backends)
                        .and_return(expected)
    end

    it "sets 'backend' to default when no 'app_id' start with match is found" do
      expected = simpkv_options.dup
      expected['app_id'] = 'other_myapp'
      expected['backend'] = 'default'
      is_expected.to run.with_params({ 'app_id' => 'other_myapp' }, backends)
                        .and_return(expected)
    end

    it "ignores 'app_id' when 'backend' is specified" do
      expected = simpkv_options.dup
      expected['app_id'] = 'myapp1'
      expected['backend'] = 'default'
      is_expected.to run.with_params({ 'app_id' => 'myapp1', 'backend' => 'default' },
        backends).and_return(expected)
    end
  end
end
