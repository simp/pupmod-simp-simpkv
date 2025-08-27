module Acceptance::Helpers::LdapUtils
  # @return DN for a folder path
  #
  # @param folder Folder path
  # @param base_dn Base DN
  #
  def build_folder_dn(folder, base_dn)
    parts = folder.split('/')
    dn = ''
    parts.reverse_each { |subfolder| dn += "ou=#{subfolder}," }
    dn += base_dn
    dn
  end

  # @return DN for a key path
  #
  # @param key_path Key path
  # @param base_dn Base DN
  #
  def build_key_dn(key_path, base_dn)
    key_name = File.basename(key_path)
    key_folder = File.dirname(key_path)
    "simpkvKey=#{key_name},#{build_folder_dn(key_folder, base_dn)}"
  end

  # @return Command with the LDAP server uri option and options and
  #   environment variables for authentication
  #
  # **ASSUMES** ldap_backend_config is valid!
  #
  # @param base_command Base command to be run (e.g., ldapsearch)
  # @param ldap_backend_config ldap backend configuration
  #
  def build_ldap_command(base_command, ldap_backend_config)
    ldap_uri = ldap_backend_config['ldap_uri']
    admin_dn = ldap_backend_config.fetch('admin_dn', nil)
    admin_pw_file = ldap_backend_config.fetch('admin_pw_file', nil)

    opts = nil
    enable_tls = if ldap_uri.match?(%r{^ldapi:})
                   false
                 elsif ldap_uri.match?(%r{^ldaps:})
                   true
                 elsif ldap_backend_config.key?('enable_tls')
                   ldap_backend_config['enable_tls']
                 else
                   false
                 end

    if enable_tls
      tls_cert = ldap_backend_config['tls_cert']
      tls_key = ldap_backend_config['tls_key']
      tls_cacert = ldap_backend_config['tls_cacert']

      cmd_env = [
        "LDAPTLS_CERT=#{tls_cert}",
        "LDAPTLS_KEY=#{tls_key}",
        "LDAPTLS_CACERT=#{tls_cacert}",
      ].join(' ')

      opts = if ldap_uri.match?(%r{^ldap:})
               # StartTLS
               %(-ZZ -x -D "#{admin_dn}" -y #{admin_pw_file} -H #{ldap_uri})
             else
               # TLS
               %(-x -D "#{admin_dn}" -y #{admin_pw_file} -H #{ldap_uri})
             end

    else
      cmd_env = ''
      opts = if admin_pw_file
               # unencrypted ldap or ldapi with simple authentication
               %(-x -D "#{admin_dn}" -y #{admin_pw_file} -H #{ldap_uri})
             else
               # ldapi with EXTERNAL SASL
               "-Y EXTERNAL -H #{ldap_uri}"
             end
    end

    "#{cmd_env} #{base_command} #{opts}"
  end
end
