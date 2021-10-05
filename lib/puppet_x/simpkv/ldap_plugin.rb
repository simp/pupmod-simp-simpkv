# Plugin implementation of an interface to an LDAP key/value store
#
# Each plugin **MUST** be an anonymous class accessible only through
# a `plugin_class` local variable.
# DO NOT CHANGE THE LINE BELOW!!!!
plugin_class = Class.new do
  require 'facter'
  require 'pathname'
  require 'set'
  attr_accessor :existing_folders

  # NOTES FOR MAINTAINERS:
  # - See simpkv/lib/puppet_x/simpkv/plugin_template.rb for important
  #   information about plugin responsibilties and restrictions.
  # - One OBTW that will drive you crazy are limitations on anonymous classes.
  #   In typical Ruby code, using constants and class methods is quite normal.
  #   Unfortunately, you cannot use constants or class methods in an anonymous
  #   class, as they will be added to the Class Object, itself, and will not be
  #   available to the anonymous class. In other words, you will be tearing your
  #   hair out trying to figure out why normal Ruby code does not work here!

  ###### Public Plugin API ######

  # Construct an instance of this plugin setting its instance name
  #
  # @param name Name to ascribe to this plugin instance
  #
  def initialize(name)
    @name = name

    # Whether configuration required for public API has been set
    @configured = false

    # Path to root of the key/value tree for this plugin instance
    # - Relative to simpkv root tree
    # - Don't need the the 'ldap/' prefix the simpkv adapter adds to @name...
    #   just want the configured id
    @instance_path = File.join('instances', @name.gsub(%r{^ldap/},''))

    # Maintain a list of folders that already exist to reduce the number of
    # unnecessary ldap add operations over the lifetime of this plugin instance
    @existing_folders = Set.new

    # Configuration to be set in configure()
    # - Base DN of the simpkv tree
    # - Number of times to retry an LDAP operation if the server reports it
    #   is busy
    # - Base LDAP commands, each of which includes any environment variables,
    #   general standard options and any command-specific options
    @base_dn = nil
    @retries = nil
    @ldapadd = nil
    @ldapdelete = nil
    @ldapmodify = nil
    @ldapsearch = nil

    Puppet.debug("#{@name} simpkv plugin constructed")
  end

  # Configure this plugin instance using global and plugin-specific
  # configuration found in options
  #
  # The plugin-specific configuration will be found in
  # `options['backends'][ options['backend'] ]`:
  #
  # * `ldap_uri`:   Required. The LDAP server URI.
  #                 - This can be a LDAPI socket path or an ldap/ldaps URI
  #                   specifying host and port.
  #                 - When using an 'ldap://' URI with StartTLS, `enable_tls`
  #                   must be true and `tls_cert`, `tls_key`, and `tls_cacert`
  #                   must be configured.
  #                 - When using an 'ldaps://' URI, `tls_cert`, `tls_key`, and
  #                   `tls_cacert` must be configured.
  #
  # * `base_dn`:    Optional. The root DN for the 'simpkv' tree in LDAP.
  #                 - Defaults to 'ou=simpkv,o=puppet,dc=simp'
  #                 - Must already exist
  #
  # * `admin_dn`:   Optional. The bind DN for simpkv administration.
  #                 - Defaults to 'cn=Directory_Manager'.
  #                 - This identity must have permission to modify the LDAP tree
  #                   below `base_dn`.
  #
  # * `admin_pw_file`: Required for all but LDAPI. A file containing the simpkv
  #                    adminstration password.
  #                    - Will be used for authentication when set, even with
  #                      LDAPI.
  #                    - When unset for LDAPI, the admin_dn is assumed to
  #                      be properly configured for external EXTERNAL SASL
  #                      authentication for the user compiling the manifest
  #                      (e.g., 'puppet' for 'puppet agent', 'root' for
  #                      'puppet apply' and the Bolt user for Bolt plans).
  #
  # * `enable_tls`: Optional. Whether to enable TLS.
  #                 - Defaults to true when `ldap_uri` is an 'ldaps://' URI,
  #                   otherwise defaults to false.
  #                 - Must be set to true to enable StartTLS when using an
  #                  'ldap://' URI.
  #                 - When true `tls_cert`, `tls_key` and `tls_cacert` must
  #                   be set.
  #
  # * `tls_cert`:   Required for StartTLS or TLS. The certificate file.
  # * `tls_key`:    Required for StartTLS or TLS. The key file.
  # * `tls_cacert`: Required for StartTLS or TLS. The cacert file.
  # * `retries`:    Optional. Number of times to retry an LDAP operation if the
  #                 server reports it is busy.
  #                 - Defaults to 1.
  #
  # @param options Hash of global simpkv and backend-specific options
  #
  # @raise RuntimeError if ldap_uri is malformed, any required configuration is
  #   missing from options, or cannot connect to the LDAP server
  #
  def configure(options)
    # backend config should already have been verified by simpkv adapter, but
    # just in case...
    unless (
        options.is_a?(Hash) &&
        options.has_key?('backend') &&
        options.has_key?('backends') &&
        options['backends'].is_a?(Hash) &&
        options['backends'].has_key?(options['backend']) &&
        options['backends'][ options['backend'] ].has_key?('id') &&
        options['backends'][ options['backend'] ].has_key?('type') &&
        (options['backends'][ options['backend'] ]['type'] == 'ldap')
    )
      raise("Plugin misconfigured: #{options}")
    end

    # parse and validate backend config options and then set variables needed
    # for LDAP operations
    opts = parse_config(options['backends'][options['backend']])
    @base_dn = opts[:base_dn]
    @retries = opts[:retries]
    set_base_ldap_commands(opts[:cmd_env], opts[:base_opts])

    # verify LDAP config allows access and then ensure the base tree with
    # 'globals' and 'environments' sub-folders is in place
    verify_ldap_access
    ensure_instance_tree

    @configured = true
    Puppet.debug("#{@name} simpkv plugin configured")
  end

  # @return unique identifier assigned to this plugin instance
  def name
    @name
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
    Puppet.debug("#{@name} delete(#{key})")
    unless @configured
      return {
        :result  => false,
        :err_msg => 'Internal error: delete called before configure'
      }
    end

    full_key_path =  File.join(@instance_path, key)
    cmd = %Q{#{@ldapdelete} "#{path_to_dn(full_key_path)}"}
    deleted = false
    err_msg = nil
    done = false
    retries = @retries
    until done
      result = run_command(cmd)
      case result[:exitstatus]
      when 0
        deleted = true
        done = true
      when ldap_code_no_such_object
        deleted = true
        done = true
      when ldap_code_server_is_busy
        if (retries == 0)
          err_msg = result[:stderr]
          done = true
        end
      else
        err_msg = result[:stderr]
        done = true
      end
      retries -= 1
    end

    { :result => deleted, :err_msg => err_msg }
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
    Puppet.debug("#{@name} deletetree(#{keydir})")
    unless @configured
      return {
        :result  => false,
        :err_msg => 'Internal error: deletetree called before configure'
      }
    end

    full_keydir_path =  File.join(@instance_path, keydir)
    cmd = %Q{#{@ldapdelete} -r "#{path_to_dn(full_keydir_path, false)}"}
    deleted = false
    err_msg = nil
    done = false
    retries = @retries
    until done
      result = run_command(cmd)
      case result[:exitstatus]
      when 0
        deleted = true
        done = true
      when ldap_code_no_such_object
        deleted = true
        done = true
      when ldap_code_server_is_busy
        if (retries == 0)
          err_msg = result[:stderr]
          done = true
        end
      else
        err_msg = result[:stderr]
        done = true
      end
      retries -= 1
    end

    if deleted
      existing_folders.delete(full_keydir_path)
      parent_path = full_keydir_path + "/"
      existing_folders.delete_if { |path| path.start_with?(parent_path) }
    end

    { :result => deleted, :err_msg => err_msg }
  end

  # Returns whether key or key folder exists in the configured backend.
  #
  # @param key String key or key folder to check
  #
  # @return results Hash
  #   * :result - Boolean indicating whether key/key folder exists;
  #     nil if could not be determined
  #   * :err_msg - String. Explanatory text when status could not be
  #     determined; nil otherwise.
  #
  def exists(key)
    Puppet.debug("#{@name} exists(#{key})")
    unless @configured
      return {
        :result  => nil,
        :err_msg => 'Internal error: exists called before configure'
      }
    end

    # don't know if the key path is to a key or a folder so need to create a
    # search filter for both an RDN of ou=<key> or an RDN simpkvKey=<key>.
    full_key_path =  File.join(@instance_path, key)
    dn = path_to_dn(File.dirname(full_key_path), false)
    leaf = File.basename(key)
    search_filter = "(|(ou=#{leaf})(simpkvKey=#{leaf}))"
    cmd = [
      @ldapsearch,
      '-b', %Q{"#{dn}"},
      '-s one',
      %Q{"#{search_filter}"},
      '1.1'                   # only print out the dn, no attributes
    ].join(' ')

    found = false
    err_msg = nil
    done = false
    retries = @retries
    until done
      result = run_command(cmd)
      case result[:exitstatus]
      when 0
        # Parent DN exists, but search may or may not have returned a result
        # (i.e. search may have returned no matches). Have to parse console
        # output to see if a dn was returned.
        found = true if result[:stdout].match(%r{^dn: (ou=#{leaf})|(simpkvKey=#{leaf}),#{dn}})
        done = true
      when ldap_code_no_such_object
        # Some part of the parent DN does not exist, so it does not exist!
        done = true
      when ldap_code_server_is_busy
        if (retries == 0)
          found = nil
          err_msg = result[:stderr]
          done = true
        end
      else
        found = nil
        err_msg = result[:stderr]
        done = true
      end
      retries -= 1
    end

    { :result => found, :err_msg => err_msg }
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
    Puppet.debug("#{@name} get(#{key})")
    unless @configured
      return {
        :result  => nil,
        :err_msg => 'Internal error: get called before configure'
      }
    end

    full_key_path =  File.join(@instance_path, key)
    cmd = %Q{#{@ldapsearch} -b "#{path_to_dn(full_key_path)}"}
    value = nil
    err_msg = nil
    done = false
    retries = @retries
    until done
      result = run_command(cmd)
      case result[:exitstatus]
      when 0
          match = result[:stdout].match(/^simpkvJsonValue: (.*?)$/)
          if match
            value = match[1]
          else
            err_msg = "Key retrieval did not return key/value entry:"
            err_msg += "\n#{result[:stdout]}"
          end
          done = true
      when ldap_code_server_is_busy
        if (retries == 0)
          err_msg = result[:stderr]
          done = true
        end
      else
        err_msg = result[:stderr]
        done = true
      end
      retries -= 1
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
    Puppet.debug("#{@name} list(#{keydir})")
    unless @configured
      return {
        :result  => nil,
        :err_msg => 'Internal error: list called before configure'
      }
    end
    full_keydir_path =  File.join(@instance_path, keydir)

    cmd = [
      @ldapsearch,
      '-b', %Q{"#{path_to_dn(full_keydir_path, false)}"},
      '-s', 'one',
    ].join(' ')

    ldif_out = nil
    err_msg = nil
    done = false
    retries = @retries
    until done
      result = run_command(cmd)
      case result[:exitstatus]
      when 0
        ldif_out = result[:stdout]
        done = true
      when ldap_code_no_such_object
        err_msg = result[:stderr]
        done = true
      when ldap_code_server_is_busy
        if (retries == 0)
          err_msg = result[:stderr]
          done = true
        end
      else
        err_msg = result[:stderr]
        done = true
      end
      retries -= 1
    end

    list = nil
    unless ldif_out.nil?
      if ldif_out.empty?
        list = { :keys => {}, :folders => [] }
      else
        list = parse_list_ldif(ldif_out)
      end
    end

    { :result => list, :err_msg => err_msg }
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
    Puppet.debug("#{@name} put(#{key},...)")
    unless @configured
      return {
        :result  => false,
        :err_msg => 'Internal error: put called before configure'
      }
    end

    full_key_path =  File.join(@instance_path, key)

    # We want to add the key/value entry if it does not exist, but only modify
    # the value if its current value does not match the desired value.
    # The modification restriction ensures that we do not update LDAP's
    # modifyTimestamp unnecessarily. Accurate timestamps are important for
    # keystore auditing!
    #
    # The tricky part is this add/update logic is that, at any point in this
    # process, something else could be modifying the database at the same time.
    # So, there is no point in checking for the existence of the key's folders
    # or its key/value entry, because that info may not be accurate at the time
    # we request our changes.  Instead, try to add each folder/key node
    # individually, and handle any "Already exists" failures appropriately for
    # each node.

    results = nil
    ldap_results = ensure_folder_path( File.dirname(full_key_path) )
    if ldap_results[:success]
      # first try ldapadd for the key/value entry
      ldif = entry_add_ldif(full_key_path, value)

      Puppet.debug("#{@name} Attempting add for #{full_key_path}")
      ldap_results = ldap_add(ldif, false)

      if ldap_results[:success]
        results = { :result => true, :err_msg => nil }
      elsif (ldap_results[:exitstatus] == ldap_code_already_exists)
        Puppet.debug("#{@name} #{full_key_path} already exists")
        # ldapmodify only if necessary
        results = update_value_if_changed(key, value)
      else
        results = { :result => false, :err_msg => ldap_results[:err_msg] }
      end
    else
      results = { :result => false, :err_msg => ldap_results[:err_msg] }
    end

    results
  end

  ###### Internal Methods ######

  # Ensure all folders in a folder path are present.
  #
  # Adds any folder not in @existing_folders
  #
  # @param folder_path the folder path to ensure
  #
  # @return results Hash
  #   * :success - Whether all folders are now present
  #   * :exitstatus - 0 when all folders are now present or the exit code of
  #     the first folder add operation that failed
  #   * :err_msg - nil when all folders are now present or the error message
  #     of the first folder add operation that failed
  #
  def ensure_folder_path(folder_path)
    Puppet.debug("#{@name} ensure_folder_path(#{folder_path})")
    # Handle each folder separately instead of all at once, so we don't have to
    # use log scraping to understand what happened...log scraping is fragile!
    ldif_file = nil
    folders_ensured = true
    results = nil
    Pathname.new(folder_path).descend do |folder|
      folder_str = folder.to_s
      next if existing_folders.include?(folder_str)
      ldif = folder_add_ldif(folder_str)
      ldap_results = ldap_add(ldif, true)
      if ldap_results[:success]
        existing_folders.add(folder_str)
      else
        folders_ensured = false
        results = ldap_results
        break
      end
    end

    if folders_ensured
      results = { :success => true, :exitstatus => 0, :err_msg => nil }
    end

    results
  end

  # Ensures the basic tree for this instance is created below the base DN
  #   base DN
  #   | - instances
  #   | | - <instance name>
  #   | | | - globals
  #   | | | - environments
  #   | | --
  #   | --
  #   --
  def ensure_instance_tree
    [
      File.join(@instance_path, 'globals'),
      File.join(@instance_path, 'environments')
    ].each do | folder|
      # Have already verified access to the base DN, so going to *assume* any
      # failures here are transient and will ignore them for now. If there is
      # a persistent problem, it will be caught in the first key storage
      # operation.
      ensure_folder_path(folder)
    end
  end

  # @return LDIF to add a simpkvEntry containing a key/value pair
  def entry_add_ldif(key, value)
    <<~EOM
      dn: #{path_to_dn(key)}
      objectClass: simpkvEntry
      objectClass: top
      simpkvKey: #{File.basename(key)}
      simpkvJsonValue: #{value}
    EOM
  end

  # @return LDIF to modify the value (simpkvJsonValue) of a
  # a simpkvEntry containing a key/value pair
  def entry_modify_ldif(key, value)
    <<~EOM
      dn: #{path_to_dn(key)}
      changetype: modify
      replace: simpkvJsonValue
      simpkvJsonValue: #{value}
    EOM
  end

  # @return LDIF to add a folder (organizationalUnit)
  def folder_add_ldif(folder)
    <<~EOM
      dn: #{path_to_dn(folder, false)}
      ou: #{File.basename(folder)}
      objectClass: top
      objectClass: organizationalUnit
    EOM
  end

  # Execute ldapadd with the specified LDIF content
  #
  # - Used to add a folder (organizationalUnit) or a key/value pair (simpkvEntry).
  # - When ignore_already_exists is true, the attributes of the existing
  #   element will NOT be changed. So, ignore_already_exists is most useful
  #   when you want to add a folder and don't care if it already exists.
  #
  # @param ldif LDIF with key/value pair or folder to add
  # @param ignore_already_exists Whether to ignore 'Already exists' failure
  # @return results Hash
  #   * :success - Whether the ldapadd succeeded; Will be true when
  #     the ldapadd failed with 'Already exists' return code, but
  #     ignore_already_exists is true.
  #   * :exitstatus - The exitstatus of the ldapadd operation
  #   * :err_msg - nil when :success is true or the error message of the
  #     ldapadd operation
  #
  def ldap_add(ldif, ignore_already_exists = false)
    # Maintainers:  Comment out this line to see actual LDIF content when
    # debugging. Since may contain sensitive info, we don't want to allow this
    # output normally.
    #Puppet.debug( "#{@name} add ldif:\n#{ldif}" )
    ldif_file = Tempfile.new('ldap_add')
    ldif_file.puts(ldif)
    ldif_file.close

    cmd = "#{@ldapadd} -f #{ldif_file.path}"
    added = false
    exitstatus = nil
    err_msg = nil
    done = false
    retries = @retries
    until done
      result = run_command(cmd)
      case result[:exitstatus]
      when 0
        added = true
        exitstatus = 0
        done = true
      when ldap_code_already_exists
        if ignore_already_exists
          added = true
          exitstatus = 0
        else
          err_msg = result[:stderr]
          exitstatus = result[:exitstatus]
        end
        done = true
      when ldap_code_server_is_busy
        if (retries == 0)
          err_msg = result[:stderr]
          exitstatus = result[:exitstatus]
          done = true
        end
      else
        err_msg = result[:stderr]
        exitstatus = result[:exitstatus]
        done = true
      end
      retries -= 1
    end

    { :success => added, :exitstatus => exitstatus, :err_msg => err_msg }
  ensure
    ldif_file.close if ldif_file
    ldif_file.unlink if ldif_file
  end

  # LDAP return code for 'Already exists'
  def ldap_code_already_exists
    68
  end

  # LDAP return code for 'No such object'
  def ldap_code_no_such_object
    32
  end

  # LDAP return code for 'Server is busy'
  def ldap_code_server_is_busy
    51
  end

  # Execute ldapmodify with the specified LDIF content
  #
  # - Used to modify the value (simpkvJsonValue) of an existing key/value pair
  #   (simpkvEntry)
  #
  # @param ldif LDIF with modification to affect
  # @return results Hash
  #   * :success - Whether the ldapmodify succeeded
  #   * :exitstatus - The exitstatus of the ldapmodify operation
  #   * :err_msg - nil when :success is true or the error message of the
  #     ldapmodify operation
  #
  def ldap_modify(ldif)
    # Maintainers:  Comment out this line to see actual LDIF content when
    # debugging. Since may contain sensitive info, we don't want to allow this
    # output normally.
    #Puppet.debug( "#{@name} modify ldif:\n#{ldif}" )
    ldif_file = Tempfile.new('ldap_modify')
    ldif_file.puts(ldif)
    ldif_file.close

    cmd =  "#{@ldapmodify} -f #{ldif_file.path}"
    modified = false
    exitstatus = nil
    err_msg = nil
    done = false
    retries = @retries
    until done
      result = run_command(cmd)
      case result[:exitstatus]
      when 0
        modified = true
        done = true
      when ldap_code_no_such_object
        # DN got removed out from underneath us. Going to just accept this
        # failure for now, as unclear the complication in the logic to turn
        # around and add the entry is worth it.
        err_msg = result[:stderr]
        done = true
      when ldap_code_server_is_busy
        if (retries == 0)
          err_msg = result[:stderr]
          done = true
        end
      else
        err_msg = result[:stderr]
        done = true
      end
      exitstatus = result[:exitstatus]
      retries -= 1
    end

    { :success => modified, :exitstatus => exitstatus, :err_msg => err_msg }
  ensure
    ldif_file.close if ldif_file
    ldif_file.unlink if ldif_file

  end

  # @return DN corresponding to a path
  #
  # @param path Folder or key path in a keystore
  # @param leaf_is_key Whether the final node in this path is a key
  #
  def path_to_dn(path, leaf_is_key = true)
    parts = path.split('/')
    dn = nil
    if parts.empty?
      dn = @base_dn
    else
      attribute = leaf_is_key ? 'simpkvKey' : 'ou'
      dn = "#{attribute}=#{parts.pop}"
      parts.reverse.each do |folder|
        dn += ",ou=#{folder}"
      end
      dn += ",#{@base_dn}"
    end

    dn
  end

  # Extract and validate configuration for use with ldapsearch, ldapadd,
  # ldapmodify, and ldapdelete commands
  #
  # Parses the following configuration
  # * `ldap_uri`:   Required. The LDAP server URI.
  #                 - This can be a LDAPI socket path or an ldap/ldaps URI
  #                   specifying host and, optionally, port.
  #                 - When using an 'ldap://' URI with StartTLS, `enable_tls`
  #                   must be true and `tls_cert`, `tls_key`, and `tls_cacert`
  #                   must be configured.
  #                 - When using an 'ldaps://' URI, `tls_cert`, `tls_key`, and
  #                   `tls_cacert` must be configured.
  #
  # * `base_dn`:    Optional. The root DN for the 'simpkv' tree in LDAP.
  #                 - Defaults to 'ou=simpkv,o=puppet,dc=simp'
  #                 - Must already exist
  #
  # * `admin_dn`:   Optional. The bind DN for simpkv administration.
  #                 - Defaults to 'cn=Directory_Manager'
  #                 - This identity must have permission to modify the LDAP tree
  #                   below `base_dn`.
  #
  # * `admin_pw_file`: Required for all but LDAPI. A file containing the simpkv
  #                    adminstration password.
  #                    - Will be used for authentication when set, even with
  #                      LDAPI.
  #                    - When unset for LDAPI, the admin_dn is assumed to
  #                      be properly configured for external EXTERNAL SASL
  #                      authentication for the user compiling the manifest
  #                      (e.g., 'puppet' for 'puppet agent', 'root' for
  #                      'puppet apply' and the Bolt user for Bolt plans).
  #
  # * `enable_tls`: Optional. Whether to enable TLS.
  #                 - Defaults to true when `ldap_uri` is an 'ldaps://' URI,
  #                   otherwise defaults to false.
  #                 - Must be set to true to enable StartTLS when using an
  #                  'ldap://' URI.
  #                 - When true `tls_cert`, `tls_key` and `tls_cacert` must
  #                   be set.
  #
  # * `tls_cert`:   Required for StartTLS or TLS. The certificate file.
  # * `tls_key`:    Required for StartTLS or TLS. The key file.
  # * `tls_cacert`: Required for StartTLS or TLS. The cacert file.
  # * `retries`:    Optional. Number of times to retry an LDAP operation if the
  #                 server reports it is busy.
  #                 - Defaults to 1.
  #
  # @param config Hash backend-specific options
  #
  # @return parsed config Hash
  #   * :base_dn - Base DN of the simpkv tree
  #   * :cmd_env - Any environment variables required for the ldap* commands
  #   * :base_opts - Base options for the ldap* commands which include the LDAP
  #                server URL and authentication options
  #   * :retries - Number of times a ldap* command should be retried
  #
  # @raise RuntimeError upon any of the following validation failures:
  #   * 'ldap_uri' option is missing
  #   * 'ldap_uri' does not begin with 'ldapi:', 'ldap:', or 'ldaps:'
  #   * 'admin_pw_file' is not configured
  #   * 'admin_pw_file' file does not exist
  #   * TLS configuration is not complete when 'ldap_uri' begins with 'ldaps:'
  #     or 'enable_tls' present and set to true
  #
  def parse_config(config)
    opts = {}

    ldap_uri = config['ldap_uri']
    raise("Plugin missing 'ldap_uri' configuration") if ldap_uri.nil?

    # TODO this regex for URI or socket can be better!
    unless ldap_uri.match(%r{^(ldapi|ldap|ldaps)://\S.})
      raise("Invalid 'ldap_uri' configuration: #{ldap_uri}")
    end

    if config.key?('base_dn')
      # TODO Detect when non-escaped characters exist and fail?
      opts[:base_dn] = config['base_dn']
    else
      opts[:base_dn] = 'ou=simpkv,o=puppet,dc=simp'
      Puppet.debug("simpkv plugin #{name}: Using default base DN #{opts[:base_dn]}")
    end

    admin_dn = nil
    if config.key?('admin_dn')
      admin_dn = config['admin_dn']
    else
      #FIXME Should not use admin for whole tree
      admin_dn = 'cn=Directory_Manager'
      Puppet.debug("simpkv plugin #{name}: Using default simpkv admin DN #{admin_dn}")
    end

    admin_pw_file = config.fetch('admin_pw_file', nil)
    unless ldap_uri.start_with?('ldapi')
      raise("Plugin missing 'admin_pw_file' configuration") if admin_pw_file.nil?
    end

    if admin_pw_file
      raise("Configured 'admin_pw_file' #{admin_pw_file} does not exist") unless File.exist?(admin_pw_file)
    end

    if tls_enabled?(config)
      opts[:cmd_env], extra_opts = parse_tls_config(config)
      opts[:base_opts] = %Q{#{extra_opts} -x -D "#{admin_dn}" -y #{admin_pw_file} -H #{ldap_uri}}
    else
      opts[:cmd_env] = ''
      if admin_pw_file
        # unencrypted ldap or ldapi with simple authentication
        opts[:base_opts] = %Q{-x -D "#{admin_dn}" -y #{admin_pw_file} -H #{ldap_uri}}
      else
        # ldapi with EXTERNAL SASL
        opts[:base_opts] = "-Y EXTERNAL -H #{ldap_uri}"
      end
    end

    if config.key?('retries')
      opts[:retries] = config['retries']
    else
      opts[:retries] = 1
      Puppet.debug("simpkv plugin #{name}: Using retries = #{opts[:retries]}")
    end

    opts
  end

  # Parse the LDIF output for a ldapsearch that corresponds to a folder
  # list operation
  #
  # @param ldif_out  LDIF console output of the ldapsearch operation
  #
  # @return folder listing results Hash
  #   * :keys - Hash of the key/value pairs for keys in the folder
  #   * :folders - Array of sub-folder names
  #
  def parse_list_ldif(ldif_out)
    folders = []
    keys = {}
    ldif_out.split(/^dn: /).each do |ldif|
      next if ldif.strip.empty?
      if ldif.match(/objectClass: organizationalUnit/i)
        rdn = ldif.split("\n").first.split(',').first
        folder_match = rdn.match(/^ou=(\S+)$/)
        if folder_match
          folders << folder_match[1]
        else
          Puppet.debug("Unexpected organizationalUnit entry:\n#{ldif}")
        end
      elsif ldif.match(/objectClass: simpkvEntry/i)
        key_match = ldif.match(/simpkvKey: (\S+)/i)
        if key_match
          key = key_match[1]
          value_match = ldif.match(/simpkvJsonValue: (\{.+?\})\n/i)
          if value_match
            keys[key] = value_match[1]
          else
             Puppet.debug("simpkvEntry missing simpkvJsonValue:\n#{ldif}")
          end
        else
           Puppet.debug("simpkvEntry missing simpkvKey:\n#{ldif}")
        end
      else
        Puppet.debug("Found unexpected object in simpkv tree:\n#{ldif}")
      end
    end
    { :keys => keys, :folders => folders }
  end

  # @return Pair of string modifiers for StartTLS/TLS via ldap* commands:
  #   [ <LDAP command environment>, <Additional LDAP command base options> ]
  #
  # @param config Hash backend-specific options
  #
  def parse_tls_config(config)
    tls_cert = config.fetch('tls_cert', nil)
    tls_key = config.fetch('tls_key', nil)
    tls_cacert = config.fetch('tls_cacert', nil)

    if tls_cert.nil? || tls_key.nil? || tls_cacert.nil?
      err_msg = "TLS configuration incomplete:"
      err_msg += ' tls_cert, tls_key, and tls_cacert must all be set'
      raise(err_msg)
    end

    cmd_env = [
      "LDAPTLS_CERT=#{tls_cert}",
      "LDAPTLS_KEY=#{tls_key}",
      "LDAPTLS_CACERT=#{tls_cacert}"
    ].join(' ')

    if config['ldap_uri'].match(/^ldap:/)
      # StartTLS
      extra_opts = '-ZZ'
    else
      # TLS
      extra_opts = ''
    end

    [ cmd_env, extra_opts ]
  end

  # Execute a command
  #
  # - Pipes within the command can cause inconsistent results.
  #   - DON'T USE THEM.
  #   - TODO. We don't currently check for '|' and fail , because we use '|'
  #     as the OR operator within a LDAP search term. Need more sophisticated
  #     check than simply the existence of a '|' in the command string!
  # - This method does not wrap the execution with a Timeout block, because
  #   the commands being executed by this plugin (ldapsearch, ldapadd, etc.)
  #   have built-in timeout mechanisms.
  #
  # @param command The command to execute
  #
  # @return results Hash
  #   * :success -  Whether the exist status was 0
  #   * :exitstatus - The exit status
  #   * :stdout - Messages sent to stdout
  #   * :stderr - Messages sent to stderr
  #
  def run_command(command)
    Puppet.debug( "#{@name} executing: #{command}" )

    out_pipe_r, out_pipe_w = IO.pipe
    err_pipe_r, err_pipe_w = IO.pipe
    pid = spawn(command, :out => out_pipe_w, :err => err_pipe_w)
    out_pipe_w.close
    err_pipe_w.close

    Process.wait(pid)
    exitstatus = $?.nil? ? nil : $?.exitstatus
    stdout = out_pipe_r.read
    out_pipe_r.close
    stderr = err_pipe_r.read
    err_pipe_r.close

    stderr = "#{command} failed:\n#{stderr}" if exitstatus != 0

    {
      :success    => (exitstatus == 0),
      :exitstatus => exitstatus,
      :stdout     => stdout,
      :stderr     => stderr
    }
  end

  # Verifies ldap* commands exist and sets base commands used in LDAP
  # operations
  #
  # @param cmd_env  Any environment variables required for the ldap* commands
  # @param base_opts  Base options for the ldap* commands which include the LDAP
  #   server URL and authentication options
  #
  # @raise RuntimeError if ldapadd, ldapdelete, ldapmodify, or ldapsearch
  #   commands cannot be found
  #
  def set_base_ldap_commands(cmd_env, base_opts)
    # make sure all the openldap-utils commands we need are available
    ldapadd = Facter::Core::Execution.which('ldapadd')
    ldapdelete = Facter::Core::Execution.which('ldapdelete')
    ldapmodify = Facter::Core::Execution.which('ldapmodify')
    ldapsearch = Facter::Core::Execution.which('ldapsearch')

    {
      'ldapadd'    => ldapadd,
      'ldapdelete' => ldapdelete,
      'ldapmodify' => ldapmodify,
      'ldapsearch' => ldapsearch
    }.each do |base_cmd, cmd|
      if cmd.nil?
        raise("Missing required #{base_cmd} command. Ensure openldap-clients RPM is installed")
      end
    end

    @ldapsearch = [
      cmd_env,
      ldapsearch,
      base_opts,

      # TODO switch to ldif_wrap when we drop support for EL7
      # - EL7 only supports ldif-wrap
      # - EL8 says it supports ldif_wrap (--help and man page), but actually
      #   accepts ldif-wrap or ldif_wrap
      '-o "ldif-wrap=no" -LLL'
    ].join(' ')

    @ldapadd = [
      cmd_env,
      ldapadd,
      base_opts,
    ].join(' ')

    @ldapmodify = [
      cmd_env,
      ldapmodify,
      base_opts,
    ].join(' ')

    @ldapdelete = [
      cmd_env,
      ldapdelete,
      base_opts,
    ].join(' ')
  end

  # @return Whether configuration enables TLS
  #
  # @param config Hash backend-specific options
  def tls_enabled?(config)
    tls_enabled = false
    ldap_uri = config['ldap_uri']
    if ldap_uri.start_with?('ldapi')
      tls_enabled = false
    elsif ldap_uri.match(/^ldaps:/)
      tls_enabled = true
    elsif config.key?('enable_tls')
      tls_enabled = config['enable_tls']
    else
      tls_enabled = false
    end

    tls_enabled
  end

  # Updates the value of an existing key if the value has changed
  #
  # Do nothing if value is the same, as we don't want to change LDAP's
  # modifyTimestamp
  #
  # @param key String key
  # @param value String value
  #
  # @return results Hash
  #   * :result - Boolean indicating whether operation succeeded
  #   * :err_msg - String. Explanatory text upon failure; nil otherwise.
  #
  def update_value_if_changed(key, value)
    results = nil
    full_key_path =  File.join(@instance_path, key)
    current_result = get(key)
    if current_result[:result]
      if current_result[:result] != value
        Puppet.debug("#{@name} Attempting modify for #{full_key_path}")
        ldif = entry_modify_ldif(full_key_path, value)
        ldap_results = ldap_modify(ldif)
        if ldap_results[:success]
          results = { :result => true, :err_msg => nil }
        else
          results = { :result => false, :err_msg => ldap_results[:err_msg] }
        end
      else
        # no change needed
        Puppet.debug("#{@name} #{full_key_path} value already correct")
        results = { :result => true, :err_msg => nil }
      end
    else
      err_msg = "Failed to retrieve current value for comparison: #{current_result[:err_msg]}"
      results = { :result => false, :err_msg => err_msg }
    end

    results
  end

  # Verifies can access the LDAP server at the base DN
  #
  def verify_ldap_access
    cmd = [
      @ldapsearch,
      '-b', %Q{"#{@base_dn}"},
      '-s base',
      '1.1'             # only print out the dn, no attributes
    ].join(' ')

    found = false
    err_msg = nil
    done = false
    retries = @retries
    until done
      result = run_command(cmd)
      case result[:exitstatus]
      when 0
        found = true
        done = true
      when ldap_code_server_is_busy
        if (retries == 0)
          err_msg = result[:stderr]
          done = true
        end
      else
        err_msg = result[:stderr]
        done = true
      end
      retries -= 1
    end

    unless found
      raise("Plugin could not access #{@base_dn}: #{err_msg}")
    end
  end
end

