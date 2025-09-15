require 'spec_helper'

describe 'simpkv::get' do
  # tell puppet-rspec to set Puppet environment to 'myenv'
  let(:environment) { 'myenv' }
  let(:key) { 'mykey' }
  let(:value) { false }
  let(:metadata) { { 'foo' => 'bar', 'baz' => 42 } }
  let(:serialized_value) { '{"value":false,"metadata":{"foo":"bar","baz":42}}' }

  # Going to use file plugin and the test plugins in spec/support/test_plugins
  # for these unit tests.
  before(:each) do
    # set up configuration for the file plugin
    @tmpdir = Dir.mktmpdir
    @root_path_test_file      = File.join(@tmpdir, 'simpkv', 'test_file')
    @root_path_default_app_id = File.join(@tmpdir, 'simpkv', 'default_app_id')
    @root_path_default        = File.join(@tmpdir, 'simpkv', 'default')
    options_base = {
      'backends' => {
        # will use failer plugin for catastrophic error cases, because
        # it is badly behaved and raises exceptions on all operations
        'test_failer' => {
          'id' => 'test',
           'type'             => 'failer',
           'fail_constructor' => false # true = raise in constructor
        },
        # will use file plugin for non-catastrophic test cases
        'test_file' => {
          'id'        => 'test',
          'type'      => 'file',
          'root_path' => @root_path_test_file
        },
        'myapp' => {
          'id'        => 'default_app_id',
          'type'      => 'file',
          'root_path' => @root_path_default_app_id
        },
        'default' => {
          'id'        => 'default',
          'type'      => 'file',
          'root_path' => @root_path_default
        }
      }
    }
    @options_failer         = options_base.merge({ 'backend' => 'test_failer' })
    @options_test_file      = options_base.merge({ 'backend' => 'test_file' })
    @options_default_app_id = options_base.merge({ 'app_id'  => 'myapp10' })
    @options_default        = options_base
  end

  after(:each) do
    FileUtils.remove_entry_secure(@tmpdir)
  end

  context 'basic operation' do
    let(:test_file_keydir) { File.join(@root_path_test_file, 'environments', environment) }
    let(:default_app_id_keydir) { File.join(@root_path_default_app_id, 'environments', environment) }
    let(:default_keydir) { File.join(@root_path_default, 'environments', environment) }

    data_info.each do |summary, info|
      it "retrieves key with #{summary} value + metadata from a specific backend in options" do
        skip info[:skip] if info.key?(:skip)

        if info.key?(:deserialized_value)
          # This key is set when the entry has malformed binary data that is
          # improperly encoded as UTF-8.  Current adapter behavior is fix the
          # encoding on retrieval, but that behavior may not be needed.
          skip 'Use case may not apply to simpkv::get'
        end

        FileUtils.mkdir_p(test_file_keydir)
        key_file = File.join(test_file_keydir, key)
        File.open(key_file, 'w') { |file| file.write(info[:serialized_value]) }

        expected = { 'value' => info[:value] }
        expected['metadata'] = info[:metadata] unless info[:metadata].empty?
        is_expected.to run.with_params(key, @options_test_file).and_return(expected)
      end
    end

    it 'retrieves the key,value,metadata tuple from the default backend in options when app_id unspecified' do
      FileUtils.mkdir_p(default_keydir)
      key_file = File.join(default_keydir, key)
      File.open(key_file, 'w') { |file| file.write(serialized_value) }

      expected = { 'value' => value, 'metadata' => metadata }
      is_expected.to run.with_params(key, @options_default).and_return(expected)
    end

    it 'retrieves the key,value,metadata tuple from the default backend for app_id' do
      FileUtils.mkdir_p(default_app_id_keydir)
      key_file = File.join(default_app_id_keydir, key)
      File.open(key_file, 'w') { |file| file.write(serialized_value) }

      expected = { 'value' => value, 'metadata' => metadata }
      is_expected.to run.with_params(key, @options_default_app_id).and_return(expected)
    end

    it 'retrieves the key,value,metadata tuple from the auto-default backend when backend config missing' do
      # mocking is REQUIRED for GitLab
      allow(Dir).to receive(:exist?).with(any_args).and_call_original
      allow(Dir).to receive(:exist?).with('/var/simp/simpkv/file/auto_default').and_return(false)
      allow(FileUtils).to receive(:mkdir_p).with(any_args).and_call_original
      allow(FileUtils).to receive(:mkdir_p).with('/var/simp/simpkv/file/auto_default')
                                           .and_raise(Errno::EACCES, 'Permission denied')

      # The test's Puppet.settings[:vardir] gets created when the subject (function object)
      # is constructed
      subject
      key_file = File.join(Puppet.settings[:vardir], 'simp', 'simpkv', 'file',
        'auto_default', 'environments', environment, key)
      FileUtils.mkdir_p(File.dirname(key_file))
      File.open(key_file, 'w') { |file| file.write(serialized_value) }

      expected = { 'value' => value, 'metadata' => metadata }
      is_expected.to run.with_params(key).and_return(expected)
    end

    it 'uses global key when global config is set' do
      options = @options_default.dup
      options['global'] = true
      key_file = File.join(@root_path_default, 'globals', key)
      FileUtils.mkdir_p(File.dirname(key_file))
      File.open(key_file, 'w') { |file| file.write(serialized_value) }

      expected = { 'value' => value, 'metadata' => metadata }
      is_expected.to run.with_params(key, options).and_return(expected)
    end

    it 'fails when backend get fails and `softfail` is false' do
      is_expected.to run.with_params(key, @options_failer)
                        .and_raise_error(RuntimeError, %r{simpkv Error for simpkv::get with key='#{key}'})
    end

    it 'logs warning and return nil when backend get fails and `softfail` is true' do
      options = @options_failer.dup
      options['softfail'] = true

      is_expected.to run.with_params(key, options).and_return(nil)

      # FIXME: check warning log
    end
  end

  context 'other error cases' do
    it 'fails when key fails validation' do
      params = [ '$this is an invalid key!', @options_test_file ]
      is_expected.to run.with_params(*params)
                        .and_raise_error(ArgumentError, %r{contains disallowed whitespace})
    end

    it 'fails when simpkv cannot be added to the catalog instance' do
      allow(File).to receive(:exist?).and_return(false)
      is_expected.to run.with_params('mykey', @options_test_file)
                        .and_raise_error(LoadError, %r{simpkv Internal Error: unable to load})
    end

    it 'fails when merged simpkv options is invalid' do
      bad_options = @options_default.merge({ 'backend' => 'oops_backend' })
      is_expected.to run.with_params('mykey', bad_options)
                        .and_raise_error(ArgumentError,
        %r{simpkv Configuration Error for simpkv::get with key='mykey'})
    end
  end
end
