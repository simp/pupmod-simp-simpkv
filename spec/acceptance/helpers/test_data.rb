require 'erb'
require 'pathname'
require 'set'
require 'yaml'

module Acceptance; end
module Acceptance::Helpers; end

# Methods to create simpkv backend hieradata and simpkv_test module hieradata
# to exercise and verify simpkv functions.
#
# - See the simpkv module README.md for a description of simpkv backend
#   hieradata
# - See the simpkv_test module documentation for descriptions of the
#   type aliases corresponding to the Hashes used in the data
#   generation/transformation methods.

module Acceptance::Helpers::TestData
  # @return simpkv::options hieradata with aliases to backend configuration
  #   derived from backend_configs
  #
  # @param backend_configs Hash of backend configuration
  #   - Key is the name of the backend and its value is its backend
  #     configuration Hash.
  #     - One of the backend names must be 'default'.
  #   - Each backend configuration Hash must have 'type' specifying the plugin
  #     type and any other plugin-specific configuration required in order for
  #     the plugin to connect to its keystore.
  #   - This method will set the required backend config 'id' attribute for
  #     each backend configuration in the hieradata.
  #     - 'id' will be set to the backend's name.
  #   - Backends are *not* required to be of the same 'type'.
  #
  # @raise RuntimeError if 'default' is not one of the backend config names or
  #   if any backend configuration is missing the required 'type' attribute
  #
  def generate_backend_hiera(backend_configs)
    errors = []
    unless backend_configs.keys.include?('default')
      errors << "'default' backend missing from backend config: #{backend_configs}"
    end

    backend_configs.each do |name, config|
      unless config.include?('type')
        errors << "'#{name}' backend config missing 'type': #{config}"
      end
    end

    unless errors.empty?
      raise("ERROR: Invalid backend configuration:\n#{errors.join("\n")}")
    end

    hiera = {}
    backends = {}
    backend_configs.each do |name, config|
      backend_tag = "simpkv::backend::#{name}"
      hiera[backend_tag] = Marshal.load(Marshal.dump(config))
      hiera[backend_tag]['id'] = name
      backends[name] = "%{alias('#{backend_tag}')}"
    end

    hiera['simpkv::options'] = {
      'environment' => '%{server_facts.environment}',
      'softfail'    => false,
      'backends'    => backends
    }

    hiera
  end

  # Generates a Hash of key information for 3 app ids
  #
  # >> See the comment block in initial_key_info.erb for important details! <<
  #
  # Note that this method will map 'default' to '', in order to test the
  # behavior of the simpkv functions when there is no `app_id` attribute in
  # the `simpkv_options` parameter in a simpkv function call.
  #
  # @param app_id1 First app_id; expected to map uniquely to a backend
  # @param app_id2 Second app_id; expected to map uniquely a backend
  # @param app_id3 Third app_id; expected to map uniquely a backend
  #
  # @return Hash of key information whose format corresponds to the
  #    Simpkv_test::KeyInfo type alias
  #
  # @raise RuntimeError if the 3 app ids are not unique
  #
  def generate_initial_key_info(app_id1, app_id2, app_id3)
    ids = [ app_id1, app_id2, app_id3 ].uniq
    unless ids.size == 3
      raise("ERROR: App ids must be unique: <#{app_id1}, #{app_id2}, #{app_id3}>")
    end

    data_template = File.join(__dir__, 'files', 'initial_key_info.erb')
    appid1 = (app_id1 == 'default') ? '' : app_id1
    appid2 = (app_id2 == 'default') ? '' : app_id2
    appid3 = (app_id3 == 'default') ? '' : app_id3

    data_yaml = ERB.new(File.read(data_template)).result(binding)
    YAML.safe_load(data_yaml)
  end

  # @return transformed copy of original_key_info in which the key values and/or
  #   metadata have been modified
  #
  # TODO Change the 'file' attribute of a key specification for keys
  #      with Binary values. Currently only modifies all non-binary values,
  #      i.e., keys whose specification has a 'value' attribute.
  #
  # @param original_key_info Hash of key info whose format corresponds to
  #    the Simpkv_test::KeyInfo type alias
  #
  def modify_key_data(original_key_info)
    updated_key_info = Marshal.load(Marshal.dump(original_key_info))
    updated_key_info.each_value do |key_struct|
      key_struct.each_value do |keys|
        keys.each_value do |key_data|
          # modify non-binary values
          if key_data.key?('value')
            if key_data['value'].is_a?(Array) || key_data['value'].is_a?(String)
              key_data['value'] = key_data['value'] + key_data['value']
            end

            if key_data['value'].is_a?(TrueClass) || key_data['value'].is_a?(FalseClass)
              key_data['value'] = !key_data['value']
            end

            if key_data['value'].is_a?(Hash)
              key_data['value']['new_key'] = 'new string elem'
            end

            if key_data['value'].is_a?(Numeric)
              key_data['value'] *= 10
            end
          end

          # TODO: modify binary values specified by a 'file' attribute

          # modify metadata
          if key_data.key?('metadata')
            key_data.delete('metadata')
          else
            key_data['metadata'] = { 'version' => 2 }
          end
        end
      end
    end

    updated_key_info
  end

  # @return transformed copy of original_folder_info in which each folder
  #   listed has suffix appended to its name
  #
  # @param original_folder_info Hash of folder name info whose format
  #    corresponds to the Simpkv_test::FolderInfo type alias
  #
  # @param suffix Suffix to be appended to each original folder name
  #
  def rename_folders_in_folder_info(original_folder_info, suffix = 'new')
    new_info = {}
    original_folder_info.each do |app_id, folder_struct|
      new_info[app_id] = {}
      folder_struct.each do |folder_type, folders|
        new_info[app_id][folder_type] = {}
        folders.each do |folder, folder_data|
          new_info[app_id][folder_type]["#{folder}#{suffix}"] = folder_data
        end
      end
    end

    new_info
  end

  # @return transformed copy of original_foldername_info in which each folder
  #   listed has suffix appended to its name
  #
  # @param original_foldername_info Hash of folder name info whose format
  #    corresponds to the Simpkv_test::NameInfo type alias
  #
  # @param suffix Suffix to be appended to each original folder name
  #
  def rename_folders_in_name_info(original_foldername_info, suffix = 'new')
    new_info = Marshal.load(Marshal.dump(original_foldername_info))
    new_info.each_value do |folder_struct|
      folder_struct.each do |folder_type, folder_names|
        folder_struct[folder_type] = folder_names.map { |folder| "#{folder}#{suffix}" }
      end
    end

    new_info
  end

  # @return transformed copy of original_key_info in which the key names have been
  #    modified by suffix
  #
  # @param original_key_info Hash of key info whose format corresponds to
  #    the Simpkv_test::KeyInfo type alias
  #
  # @param suffix String to be appended to original key names
  #
  def rename_keys_in_key_info(original_key_info, suffix = 'new')
    key_info = {}
    original_key_info.each do |app_id, key_struct|
      key_info[app_id] = {}
      key_struct.each do |key_type, keys|
        key_info[app_id][key_type] = {}
        keys.each do |key, key_data|
          new_key = key + suffix
          key_info[app_id][key_type][new_key] = key_data
        end
      end
    end

    key_info
  end

  # Returns Hash of root folder names info for any non-empty root folders
  # corresponding to the key data specified in key_info
  #
  # @param key_info Hash of key info whose format corresponds to the
  #   Simpkv_test::KeyInfo type alias
  #
  # @return Hash with root name info whose format corresponds to the
  #   Simpkv_test::NameInfo type alias or {} if no non-empty root directories are
  #   found
  #
  def root_foldername_info(key_info)
    foldername_info = {}
    full_foldername_info = to_foldername_info(key_info)
    full_foldername_info.each do |app_id, folder_struct|
      folder_struct.each do |folder_type, folder_names|
        if folder_names.include?('/')
          foldername_info[app_id] = {} unless foldername_info.key?(app_id)
          foldername_info[app_id][folder_type] = [ '/' ]
        end
      end
    end

    foldername_info
  end

  # Creates a Hash of folder name info that is subset of subfolders in
  # original_foldername_name
  #
  # NOTE: No child folders beneath a selected subfolder will be included in
  #       the returned result.
  #
  # @param original_foldername_info  Hash with folder name info whose format
  #   corresponds to the Simpkv_test::NameInfo type alias
  #
  # @return Hash with subfolder name info whose format corresponds to the
  #   Simpkv_test::NameInfo type alias or {} if no subfolders are found
  #
  def select_subfolders_subset(original_foldername_info)
    subset_info = {}
    original_foldername_info.each do |app_id, folder_struct|
      folder_struct.each do |folder_type, folder_names|
        count = 0
        selected = []
        folder_names.sort.each do |folder|
          next if folder == '/'

          within_selected_folder = false
          selected.each do |subfolder|
            if folder.start_with?("#{subfolder}/")
              within_selected_folder = true
              break
            end
          end

          if !within_selected_folder && count.even?
            selected << folder
            count += 1
          end
        end

        unless selected.empty?
          subset_info[app_id] = {} unless subset_info.key?(app_id)
          subset_info[app_id][folder_type] = selected
        end
      end
    end

    subset_info
  end

  # Based on subfolder deletions specified in delete_foldernames_info, separate
  # original_key_info into a pair of Hashes: one for retained keys and one
  # for deleted keys
  #
  # @param original_key_info Hash of key info whose format corresponds to
  #   the Simpkv_test::KeyInfo type alias
  #
  # @param delete_foldernames_info Hash specifying the subfolders that have
  #   been deleted whose format corresponds to the Simpkv_test::NameInfo data
  #   type
  #
  # @param [ <retail Hash>, <delete Hash> ], where each is a Hash of key info
  #   whose format corresponds to the Simpkv_test::KeyInfo type alias
  #
  def split_key_info_per_subfolder_deletes(original_key_info, delete_foldernames_info)
    retain_index = 0
    remove_index = 1
    key_infos = [ {}, {} ]
    original_key_info.each do |app_id, key_struct|
      key_struct.each do |key_type, keys|
        keys.each do |key, key_data|
          type = retain_index
          if delete_foldernames_info.key?(app_id) &&
             delete_foldernames_info[app_id].key?(key_type)
            delete_foldernames_info[app_id][key_type].each do |folder|
              if key.start_with?("#{folder}/")
                type = remove_index
                break
              end
            end
          end

          key_infos[type][app_id] = {} unless key_infos[type].key?(app_id)
          key_infos[type][app_id][key_type] = {} unless key_infos[type][app_id].key?(key_type)
          key_infos[type][app_id][key_type][key] = key_data
        end
      end
    end

    key_infos
  end

  # Split original_key_info into an Array of key info objects
  #
  # Input key data is assigned to an output Hash in a round-robin
  # fashion per key type ('env' or 'global').
  #
  # @param original_key_info Hash of key info whose format corresponds to
  #    the Simpkv_test::KeyInfo type alias
  #
  # @param split_size Number of key info hashes to create from original_key_info
  #
  # @return Array of key info hashes, each of which whose format corresponds to
  #    the Simpkv_test::KeyInfo type alias or is empty, if input key info hash is
  #    too sparse to support the split size specified.
  #
  def split_key_info(original_key_info, split_size = 2)
    key_infos = Array.new(split_size) { {} }

    original_key_info.each do |app_id, key_struct|
      key_infos.each { |key_info| key_info[app_id] = {} }
      key_struct.each do |key_type, keys|
        key_infos.each { |key_info| key_info[app_id][key_type] = {} }

        count = 0
        keys.each do |key, key_data|
          key_infos[ count % split_size ][app_id][key_type][key] = key_data
          count += 1
        end

        key_infos.each do |key_info|
          if key_info[app_id][key_type].empty?
            key_info[app_id].delete(key_type)
          end
        end
      end

      key_infos.each do |key_info|
        if key_info[app_id].empty?
          key_info.delete(app_id)
        end
      end
    end

    key_infos
  end

  # @return Hash with full folder info derived from key_info and whose format
  #   corresponds to the Simpkv_test::FolderInfo type alias
  #
  # FIXME This method excludes any folders with binary key values in its
  # output, because simpkv_test::retrieve_and_verify_folders doesn't yet handle
  # verification of binary key data in simpk::list results
  #
  # @param key_info Hash of key information whose format corresponds to the
  #    Simpkv_test::KeyInfo type alias
  #
  # @param exclude_root_folder Whether to exclude the root folder from the returned
  #   listing
  #
  def to_folder_info(key_info, exclude_root_folder = false)
    folder_info = {}
    key_info.each do |app_id, key_struct|
      folder_info[app_id] = {}
      key_struct.each do |key_type, keys|
        folder_info[app_id][key_type] = {}
        keys.each do |key, key_data|
          keypath = Pathname.new(key)
          keypath.descend do |path|
            parent = (path.dirname.to_s == '.') ? '/' : path.dirname.to_s
            next if (parent == '/') && exclude_root_folder

            unless folder_info[app_id][key_type].key?(parent)
              folder_info[app_id][key_type][parent] = { 'keys' => {}, 'folders' => [] }
            end
            if path.to_s == key
              folder_info[app_id][key_type][parent]['keys'][path.basename.to_s] = key_data
            else
              unless folder_info[app_id][key_type][parent]['folders'].include?(path.basename.to_s)
                folder_info[app_id][key_type][parent]['folders'] << path.basename.to_s
              end
            end
          end
        end
      end
    end

    folder_info.each_value do |folder_struct|
      folder_struct.each_value do |folders|
        folders.delete_if do |_folder, folder_data|
          binary_data = false
          folder_data['keys'].each_value do |key_data|
            if key_data.key?('file')
              binary_data = true
              break
            end
          end

          binary_data
        end
      end
    end

    folder_info
  end

  # @return Hash with folder name info derived from key_info and whose format
  #   corresponds to the Simpkv_test::NameInfo type alias
  #
  # @param key_info Hash of key information whose format corresponds to the
  #    Simpkv_test::KeyInfo type alias
  #
  def to_foldername_info(key_info)
    foldername_info = {}
    key_info.each do |app_id, key_struct|
      foldername_info[app_id] = {}
      key_struct.each do |key_type, keys|
        foldername_info[app_id][key_type] = Set.new
        foldername_info[app_id][key_type] << '/'
        keys.each_key do |key|
          path = File.dirname(key)
          next if path == '.'
          Pathname.new(path).descend do |folder|
            foldername_info[app_id][key_type] << folder.to_s
          end
        end

        foldername_info[app_id][key_type] = foldername_info[app_id][key_type].to_a.sort
      end
    end

    foldername_info
  end

  # @return Hash with key name info derived from key_info and whose format
  #   corresponds to the Simpkv_test::NameInfo type alias
  #
  # @param key_info Hash of key information whose format corresponds to the
  #    Simpkv_test::KeyInfo type alias
  #
  def to_keyname_info(key_info)
    keyname_info = {}
    key_info.each do |app_id, key_struct|
      keyname_info[app_id] = {}
      key_struct.each do |key_type, keys|
        keyname_info[app_id][key_type] = keys.keys
      end
    end

    keyname_info
  end
end
