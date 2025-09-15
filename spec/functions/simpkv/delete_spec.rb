require 'spec_helper'

describe 'simpkv::delete' do
  # tell puppet-rspec to set Puppet environment to 'myenv'
  let(:environment) { 'myenv' }

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
           'fail_constructor' => false, # true = raise in constructor
        },
        # will use file plugin for non-catastrophic test cases
        'test_file' => {
          'id'        => 'test',
          'type'      => 'file',
          'root_path' => @root_path_test_file,
        },
        'myapp' => {
          'id'        => 'default_app_id',
          'type'      => 'file',
          'root_path' => @root_path_default_app_id,
        },
        'default' => {
          'id'        => 'default',
          'type'      => 'file',
          'root_path' => @root_path_default,
        },
      },
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
    let(:key) { 'mykey' }

    it 'deletes an existing key in a specific backend in options' do
      FileUtils.mkdir_p(test_file_keydir)
      key_file = File.join(test_file_keydir, key)
      FileUtils.touch(key_file)

      is_expected.to run.with_params(key, @options_test_file).and_return(true)
      expect(File.exist?(key_file)).to be false
    end

    it 'deletes an existing key in the default backend in options when app_id unspecified' do
      FileUtils.mkdir_p(default_keydir)
      key_file = File.join(default_keydir, key)
      FileUtils.touch(key_file)

      is_expected.to run.with_params(key, @options_default).and_return(true)
      expect(File.exist?(key_file)).to be false
    end

    it 'deletes an existing key in the default backend for the app_id' do
      FileUtils.mkdir_p(default_app_id_keydir)
      key_file = File.join(default_app_id_keydir, key)
      FileUtils.touch(key_file)

      is_expected.to run.with_params(key, @options_default_app_id).and_return(true)
      expect(File.exist?(key_file)).to be false
    end

    it 'deletes an existing key in the auto-default backend when backend config missing' do
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
      FileUtils.touch(key_file)

      is_expected.to run.with_params(key).and_return(true)
      expect(File.exist?(key_file)).to be false
    end

    it 'succeeds even when the key does not exist in a specific backend in options' do
      is_expected.to run.with_params(key, @options_test_file).and_return(true)
    end

    it 'uses global key when global config is set' do
      options = @options_default.dup
      options['global'] = true
      key_file = File.join(@root_path_default, 'globals', key)
      FileUtils.mkdir_p(File.dirname(key_file))
      FileUtils.touch(key_file)

      is_expected.to run.with_params(key, options).and_return(true)
      expect(File.exist?(key_file)).to be false
    end

    it 'fails when backend delete fails and `softfail` is false' do
      is_expected.to run.with_params(key, @options_failer)
                        .and_raise_error(RuntimeError, %r{simpkv Error for simpkv::delete with key='#{key}'})
    end

    it 'logs warning and return false when backend delete fails and `softfail` is true' do
      options = @options_failer.dup
      options['softfail'] = true

      is_expected.to run.with_params(key, options).and_return(false)

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
      is_expected.to run.with_params('mykey', bad_options). and_raise_error(ArgumentError,
        %r{simpkv Configuration Error for simpkv::delete with key='mykey'})
    end
  end
end
