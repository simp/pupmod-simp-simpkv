require 'spec_helper'

def prepopulate_key_files(root_dir, keydir)
  actual_keydir = File.join(root_dir, keydir)
  FileUtils.mkdir_p(actual_keydir)

  data_info.each do |description, info|
    next if (info.has_key?(:skip) || info.has_key?(:deserialized_value))

    filename = File.join(actual_keydir, description.gsub(' ','_'))
    File.open(filename, 'w') { |file| file.write(info[:serialized_value]) }
  end
end

describe 'libkv::list' do

# Going to use file plugin and the test plugins in spec/support/test_plugins
# for these unit tests.
  before(:each) do
    # set up configuration for the file plugin
    @tmpdir = Dir.mktmpdir
    @root_path_test_file = File.join(@tmpdir, 'libkv', 'test_file')
    @root_path_default_class = File.join(@tmpdir, 'libkv', 'default_class')
    @root_path_default   = File.join(@tmpdir, 'libkv', 'default')
    options_base = {
      'environment' => 'production',
      'backends'    => {
        # will use failer plugin for catastrophic error cases, because
        # it is badly behaved and raises exceptions on all operations
       'test_failer'  => {
          'id'               => 'test',
          'type'             => 'failer',
          'fail_constructor' => false  # true = raise in constructor
        },
        # will use file plugin for non-catastrophic test cases
        'test_file'  => {
          'id'        => 'test',
          'type'      => 'file',
          'root_path' => @root_path_test_file
        },
        'default.Class[Mymodule::Myclass]'  => {
          'id'        => 'default_class',
          'type'      => 'file',
          'root_path' => @root_path_default_class
        },
        'default'  => {
          'id'        => 'default',
          'type'      => 'file',
          'root_path' => @root_path_default
        }
      }
    }
    @options_failer        = options_base.merge ({ 'backend' => 'test_failer' } )
    @options_test_file     = options_base.merge ({ 'backend' => 'test_file' } )
    @options_default_class = options_base.merge ({ 'resource' => 'Class[Mymodule::Myclass]' } )
    @options_default       = options_base
  end

  after(:each) do
    FileUtils.remove_entry_secure(@tmpdir)
  end

  let(:keydir) { 'app1' }
  let(:key_list) {
    list = data_info.map { |description, info|
      if info.has_key?(:skip) || info.has_key?(:deserialized_value)
        ['skip', nil]
      else
        info_hash = { 'value' => info[:value] }
        info_hash['metadata'] = info[:metadata] unless info[:metadata].empty?
        [ "#{keydir}/#{description.gsub(' ','_')}", info_hash ]
      end
    }.to_h
    list.delete('skip')
    list
  }
  let(:test_file_env_root_dir) { File.join(@root_path_test_file, 'production') }
  let(:default_class_env_root_dir) { File.join(@root_path_default_class, 'production') }
  let(:default_env_root_dir) { File.join(@root_path_default, 'production') }

  # The tests will verify most of the function behavior without libkv::options
  # specified and then verify options merging when libkv::options is specified.

  context 'without libkv::options' do

    it 'should retrieve key list from a specific backend in options when keys exist' do
      prepopulate_key_files(test_file_env_root_dir, keydir)

      is_expected.to run.with_params(keydir, @options_test_file).
          and_return(key_list)
    end

    it 'should retrieve key list from the default backend in options when keys exist and resource unspecified' do
      prepopulate_key_files(default_env_root_dir, keydir)

      is_expected.to run.with_params(keydir, @options_default).
          and_return(key_list)
    end

    it 'should retrieve key list from the default backend for the resource when keys exist' do
      prepopulate_key_files(default_class_env_root_dir, keydir)

      is_expected.to run.with_params(keydir, @options_default_class).
          and_return(key_list)
    end

    it 'should return an empty key list when no keys exist but the directory exists' do
      # directory has to exist or it is considered a failure
      actual_keydir = File.join(default_env_root_dir, keydir)
      FileUtils.mkdir_p(actual_keydir)

      is_expected.to run.with_params(keydir, @options_default).and_return({})
    end

    it 'should fail when the directory does not exist and `softfail` is false' do
      is_expected.to run.with_params(keydir, @options_default).
        and_raise_error(RuntimeError, /libkv Error for libkv::list with keydir='#{keydir}'/)
    end

    it 'should use environment-less keydir when environment is empty' do
      options = @options_default.dup
      options['environment'] = ''
      prepopulate_key_files(@root_path_default, keydir)

      is_expected.to run.with_params(keydir, options).and_return(key_list)
    end

    it 'should fail when backend list fails and `softfail` is false' do
      is_expected.to run.with_params(keydir, @options_failer).
        and_raise_error(RuntimeError, /libkv Error for libkv::list with keydir='#{keydir}'/)
    end

    it 'should log warning and return nil when backend list fails and `softfail` is true' do
      options = @options_failer.dup
      options['softfail'] = true

      is_expected.to run.with_params(keydir, options).and_return(nil)

      #FIXME check warning log
    end
  end

  context 'with libkv::options' do
    let(:hieradata) { 'multiple_backends_missing_default' }

    it 'should merge libkv::options' do
      # @options_default will add the missing default backend config and
      # override the environment setting.  To spot check options merge (which
      # is fully tested elsewhere), remove the environment setting and verify
      # we use the default config from the local options Hash and the
      # environment from libkv::options
      options = @options_default.dup
      options.delete('environment')
      default_env_root_dir = File.join(@root_path_default, 'myenv')
      prepopulate_key_files(default_env_root_dir, keydir)

      is_expected.to run.with_params(keydir, options).and_return(key_list)
    end
  end

  context 'other error cases' do
    it 'should fail when key fails validation' do
      params = [ '$this is an invalid key dir!', @options_test_file ]
      is_expected.to run.with_params(*params).
        and_raise_error(ArgumentError, /contains disallowed whitespace/)
    end

    it 'should fail when libkv cannot be added to the catalog instance' do
      allow(File).to receive(:exists?).and_return(false)
      is_expected.to run.with_params(keydir, @options_test_file).
        and_raise_error(LoadError, /libkv Internal Error: unable to load/)
    end

    it 'should fail when merged libkv options is invalid' do
      bad_options  = @options_default.merge ({ 'backend' => 'oops_backend' } )
      is_expected.to run.with_params(keydir, bad_options).
        and_raise_error(ArgumentError,
        /libkv Configuration Error for libkv::list with keydir='#{keydir}'/)
    end
  end

end