# Plugin and store implementation of a file key/value store that resides
# on a local filesystem
#
# Each plugin **MUST** be an anonymous class accessible only through
# a `plugin_class` local variable.
plugin_class = Class.new do

  require 'fileutils'
  require 'timeout'

  # Reminder:  Do **NOT** try to set constants in this Class.new block.
  #            They don't do what you expect (are not accessible within
  #            any class methods) and pollute the Object namespace.

  ###### Public Plugin API ######

  # @return String. backend type
  def self.type
    'file'
  end

  # construct an instance of this plugin using global and plugin-specific
  # configuration found in options
  #
  # The plugin-specific configuration will be found in
  # `options['backends'][ options['backend'] ]`:
  #
  # * `root_path`: root directory path; defaults to '/var/simp/libkv/<name>' when
  #     that directory can be created or '<Puppet[:vardir]>/simp/libkv/<name>'
  #     otherwise
  # * `lock_timeout_seconds`: max seconds to wait for an exclusive file lock
  #   on a file modifying operation before failing the operation; defaults
  #   to 5 seconds
  #
  # @param name Name to ascribe to this plugin instance
  # @param options Hash of global libkv and backend-specific options
  # @raise RuntimeError if any required configuration is missing from options,
  #   the root directory cannot be created when missing, the permissions of the
  #   root directory cannot be set
  def initialize(name, options)
    # backend config should already have been verified, but just in case...
    unless (
        options.is_a?(Hash) &&
        options.has_key?('backend') &&
        options.has_key?('backends') &&
        options['backends'].is_a?(Hash) &&
        options['backends'].has_key?(options['backend']) &&
        options['backends'][ options['backend'] ].has_key?('id') &&
        options['backends'][ options['backend'] ].has_key?('type') &&
        # self is not available to an anonymous class and can't use constants,
        # so have to repeat what is already in self.type
        (options['backends'][ options['backend'] ]['type'] == 'file')
    )
      raise("libkv plugin #{name} misconfigured: #{options}")
    end

    @name = name

    default_root_path_var = File.join('/', 'var', 'simp', 'libkv', name)
    default_root_path_puppet_vardir = File.join(Puppet.settings[:vardir], 'simp', 'libkv', name)

    # set optional configuration
    backend = options['backend']
    if options['backends'][backend].has_key?('lock_timeout_seconds')
      @lock_timeout_seconds = options['backends'][backend]['lock_timeout_seconds']
    else
      @lock_timeout_seconds = 5
      Puppet.debug("libkv plugin #{name}: Using default lock timeout #{@lock_timeout_seconds}")
    end

    if options['backends'][backend].has_key?('root_path')
      @root_path = options['backends'][backend]['root_path']
    elsif Dir.exist?(default_root_path_var)
      @root_path = default_root_path_var
      Puppet.debug("libkv plugin #{name}: Using existing default root path '#{@root_path}'")
    elsif Dir.exist?(default_root_path_puppet_vardir)
      @root_path = default_root_path_puppet_vardir
      Puppet.debug("libkv plugin #{name}: Using existing default root path '#{@root_path}'")
    else
      @root_path = default_root_path_var
      Puppet.debug("libkv plugin #{name}: Using default root path '#{@root_path}'")
    end

    unless Dir.exist?(@root_path)
      begin
        FileUtils.mkdir_p(@root_path)
      rescue Exception => e
        if options['backends'][backend].has_key?('root_path')
          # someone made an explicit config error
          raise("libkv plugin #{name} Error: Unable to create configured root path '#{@root_path}': #{e.message}")
        else
          # use a default we know will be ok
          new_path = File.join(Puppet.settings[:vardir], 'simp', 'libkv', name)
          Puppet.warning("libkv plugin #{name}: Unable to create root path '#{@root_path}'. Defaulting to '#{new_path}'")
          @root_path = new_path
          FileUtils.mkdir_p(@root_path)
        end
      end
    end

    # set permissions on the root directory
    # NOTE: Group writable setting is specifically to support `simp passgen`
    # operations implemented with `puppet apply` and run as root:puppet.
    # Do not want `simp passgen` to create a file/directory that subsequent
    # `puppet agent` runs as puppet:puppet will not be able to manage.
    begin
      FileUtils.chmod(0770, @root_path)
    rescue Exception => e
      raise("libkv plugin #{name} Error: Unable to set permissions on #{@root_path}: #{e.message}")
    end

    Puppet.debug("#{@name} libkv plugin for #{@root_path} constructed")
  end


  # Deletes a `key` from the configured backend.
  #
  # @param key String key
  #
  # @return results Hash
  #   * :result - Boolean indicating whether operation succeeded
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def delete(key)
    success = nil
    err_msg = nil
    key_file = File.join(@root_path, key)
    if File.directory?(key_file)
      success = false
      err_msg = "libkv plugin #{@name}: Key specifies a folder at '#{key_file}'"
    else
      begin
        File.unlink(key_file)
        success = true
      rescue Errno::ENOENT
        # if the key doesn't exist, doesn't need to be deleted...going
        # to consider this success
        success = true
      rescue Exception => e
        success = false
        err_msg = "Delete of '#{key_file}' failed: #{e.message}"
      end
    end

    { :result => success, :err_msg => err_msg }
  end

  # Deletes a whole folder from the configured backend.
  #
  # @param keydir String key folder path
  #
  # @return results Hash
  #   * :result - Boolean indicating whether operation succeeded
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def deletetree(keydir)
    success = nil
    err_msg = nil
    dir = File.join(@root_path, keydir)
    # FIXME:  Is there an atomic way of doing this?
    if Dir.exist?(dir)
      begin
        FileUtils.rm_r(dir)
        success = true
      rescue Exception => e
        if Dir.exist?(dir)
          success = false
          err_msg = "Folder delete of '#{dir}' failed: #{e.message}"
        else
          # in case another process/thread successfully deleted the directory
          success = true
        end
      end
    else
      # if the directory doesn't exist, doesn't need to be deleted...going
      # to consider this success
      success = true
    end

    { :result => success, :err_msg => err_msg }
  end

  # Returns whether the `key` exists in the configured backend.
  #
  # @param key String key
  #
  # @return results Hash
  #   * :result - Boolean indicating whether key exists; nil if could not
  #     be determined
  #   * :err_msg - String. Explanatory text when status could not be
  #     determined; nil otherwise.
  #
  def exists(key)
    key_file = File.join(@root_path, key)
    # this simple plugin doesn't have any error cases that would be reported
    # in :err_msg
    { :result => File.exist?(key_file), :err_msg => nil }
  end

  # Retrieves the value stored at `key` from the configured backend.
  #
  # @param key String key
  #
  # @return results Hash
  #   * :result - String. Retrieved value for the key; nil if could not
  #     be retrieved
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def get(key)
    value = nil
    err_msg = nil
    key_file = File.join(@root_path, key)
    if File.directory?(key_file)
      err_msg = "libkv plugin #{@name}: Key specifies a folder at '#{key_file}'"
    else
      file = nil
      begin
        # To ensure all threads are not sharing the same file descriptor
        # do **NOT** use a File.open block!
        file = File.open(key_file, 'r')

        Timeout::timeout(@lock_timeout_seconds) do
          file.flock(File::LOCK_EX)
        end

        value = file.read
        file.close # lock released with close
        file = nil

      rescue Errno::ENOENT
        err_msg = "libkv plugin #{@name}: Key not found at '#{key_file}'"
      rescue Timeout::Error
        err_msg = "libkv plugin #{@name}: Timed out waiting for lock of key file '#{key_file}'"
      rescue Exception => e
        err_msg = "Key retrieval at '#{key_file}' failed: #{e.message}"
      ensure
        # make sure lock is released even on failure
        file.close unless file.nil?
      end
    end
    { :result => value, :err_msg => err_msg }
  end

  # Returns a listing of all keys/info pairs and sub-folders in a folder
  #
  # The list operation does not recurse through any sub-folders. Only
  # information about the specified key folder is returned.
  #
  # This implementation is best effort.  It will attempt to retrieve the
  # information in a folder and only fail if the folder itself cannot be
  # accessed.  Individual key retrieval failures will be ignored.
  #
  # @return results Hash
  #   * :result - Hash of retrieved key and sub-folder info; nil if the
  #     retrieval operation failed
  #
  #     * :keys - Hash of the key/value pairs for keys in the folder
  #     * :folders - Array of sub-folder names
  #
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def list(keydir)
    result = nil
    err_msg = nil
    dir = File.join(@root_path, keydir)
    if Dir.exist?(dir)
      result = { :keys => {}, :folders => [] }
      Dir.glob(File.join(dir,'*')).each do |entry|
        if File.directory?(entry)
          result[:folders] << entry.gsub(@root_path + File::SEPARATOR,'')
        else
          key = entry.gsub(@root_path + File::SEPARATOR,'')
          key_result = get(key)
          unless key_result[:result].nil?
            result[:keys][key] = key_result[:result]
          end
        end
      end
      result[:folders].sort!
    else
       err_msg = "libkv plugin #{@name}: Key folder '#{keydir}' not found"
    end

    { :result => result, :err_msg => err_msg }
  end

  # @return unique identifier assigned to this plugin instance
  def name
    @name
  end

  # Sets the data at `key` to a `value` in the configured backend.
  #
  # @param key String key
  # @param value String value
  #
  # @return results Hash
  #   * :result - Boolean indicating whether operation succeeded
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def put(key, value)
    success = nil
    err_msg = nil

    file = nil
    begin
      # create relative directory for the key file
      keydir = File.dirname(key)
      unless keydir == '.'
        Dir.chdir(@root_path) do
          # Group writable setting is specifically to support `simp passgen`
          # operations implemented with `puppet apply` and run as root:puppet.
          # Do not want `simp passgen` to create a file/directory that
          # subsequent `puppet agent` runs as puppet:puppet will not be able
          # to manage.
          FileUtils.mkdir_p(keydir, :mode => 0770)
        end
      end

      # create key file
      key_file = File.join(@root_path, key)
      # To ensure all threads are not sharing the same file descriptor
      # do **NOT** use a File.open block!
      # Also, don't use 'w' as it truncates file before the lock is obtained
      file = File.open(key_file, File::RDWR|File::CREAT)

      Timeout::timeout(@lock_timeout_seconds) do
        # only wrap timeout around flock, so we don't end up with partially
        # modified files
        file.flock(File::LOCK_EX)
      end

      file.rewind
      file.write(value)
      file.flush
      file.truncate(file.pos)
      file.close # lock released with close
      file = nil
      # we set the permissions here, instead of when the file was opened,
      # so that the user's umask is ignored
      # NOTE: Group writable setting is specifically to support `simp passgen`
      # operations implemented with `puppet apply` and run as root:puppet.
      # Do not want `simp passgen` to create a file/directory that
      # subsequent `puppet agent` runs as puppet:puppet will not be able
      # to manage.
      File.chmod(0660, key_file)
      success = true

    rescue Timeout::Error
      success = false
      err_msg = "libkv plugin #{@name}: Timed out waiting for lock of key file '#{key_file}'"
    rescue Exception => e
      success = false
      err_msg = "Key write to '#{key_file}' failed: #{e.message}"
    ensure
      file.close unless file.nil?
    end

    { :result => success, :err_msg => err_msg }
  end

  ###### Internal Methods ######

end
