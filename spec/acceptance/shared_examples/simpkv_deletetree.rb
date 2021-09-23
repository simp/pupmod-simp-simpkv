# Execute and verify simpkv::deletetree using the configured backend plugins.
#
# ASSUMED CONTEXT:
# The following are assumed to be available within this shared_examples context:
# * `clear_data_cmd`:  Command string to be executed on the host to clear out
#   all stored key data in the configured backends:
#   - Must work from the host being tested, even when the keystore is not
#     co-resident.
#
# * `backend_hiera`: 'simpkv::options' hash specifying backend configuration
#   - One of the backends must be named 'default'
#
# * `initial_key_info`: Hash specifying key data to be initially stored in
#   the backends:
#   - Format corresponds to the Simpkv_test::KeyInfo type alias
#   - **Must** have app_ids that correspond to the backends named in
#     backend_hiera
#
# * `validator`:  Method object that can be called to independently validate
#   backend state:
#   - Method will be called to validate whether keys are present or absent in
#     their corresponding backends, and when they are expected to be present,
#     the stored key data is correct.
#   - Method must return a Boolean indicating validation success
#   - Method should log details of validation failures for debug
#   - Method should attempt all validations before reporting failure
#   - Method must have the following parameter list
#     - Parameter 1: Hash of key information whose format corresponds to the
#                    Simpkv_test::KeyInfo type alias
#     - Parameter 2: Whether keys should exist
#                    true = verify keys are present with correct stored data
#                    false = verify keys are absent
#     - Parameter 3: Hash of backend configuration ('simpkv::options' Hash)
#     - Parameter 4: Host object on which the validator will execute commands;
#                    Is the host under test, which may not be the host on which
#                    the keystore resides.
#
shared_examples 'simpkv::deletetree tests' do |host|
  include_examples('pre-populate keystores', host)

  context "simpkv::deletetree operation on #{host}" do
    let(:initial_foldername_info) { to_foldername_info(initial_key_info) }
    let(:subfolders_to_delete) {
      subfolders = select_subfolders_subset(initial_foldername_info)
      if subfolders.empty?
        raise('No subfolders from initial_key_info selected for deletion: data too sparse')
      end

      subfolders
    }

    let(:test_key_infos_after_subfolder_delete) {
      key_infos = split_key_info_per_subfolder_deletes(initial_key_info, subfolders_to_delete)
      { :retain => key_infos[0], :remove => key_infos[1] }
    }

    # Any root folder that originally had key data.
    let(:root_folders) {
      foldername_info = root_foldername_info(initial_key_info)
      if foldername_info.empty?
        raise('All root folders found in initial_key_info are empty:  No keys!')
      end

      foldername_info
    }

    let(:remove_manifest) { 'include simpkv_test::remove_folders' }
    let(:remove_subfolders_hieradata) {
      backend_hiera.merge( {
        'simpkv_test::remove_folders::foldername_info' => subfolders_to_delete
      } )
    }

    let(:remove_root_folders_hieradata) {
      backend_hiera.merge( {
        'simpkv_test::remove_folders::foldername_info' => root_folders
      } )
    }

    let(:verify_manifest) { 'include simpkv_test::retrieve_and_verify_folders' }
    let(:verify_hieradata_after_subfolders_delete) {
      backend_hiera.merge( {
        'simpkv_test::retrieve_and_verify_folders::valid_folder_info'   => to_folder_info(test_key_infos_after_subfolder_delete[:retain]),
        'simpkv_test::retrieve_and_verify_folders::invalid_folder_info' => to_folder_info(test_key_infos_after_subfolder_delete[:remove], true)
      } )
    }

    let(:verify_empty_backend_folders_hieradata) {
      # Expected results after root directories have been removed:
      # - The root folder for the Puppet environment in each backend will no
      #   longer exist, and so a listing of if will fail.
      # - The 'globals' root folder in each backend will exist ('globals'
      #   folder is part of the infrastructure maintained by each plugin and
      #   not deletable via the simpkv functions API), but it will be empty.
      #
      env_folder_info = {}
      global_folder_info = {}
      empty_folders = { '/' => { 'keys' => {}, 'folders' => [] } }
      initial_key_info.keys.each do |app_id|
        env_folder_info[app_id] = { 'env' => Marshal.load(Marshal.dump(empty_folders)) }
        global_folder_info[app_id] = { 'global' => Marshal.load(Marshal.dump(empty_folders)) }
      end

      backend_hiera.merge( {
        'simpkv_test::retrieve_and_verify_folders::valid_folder_info'   => global_folder_info,
        'simpkv_test::retrieve_and_verify_folders::invalid_folder_info' => env_folder_info
      } )
    }

    it 'should call simpkv::deletetree with valid sub-folders without errors' do
      set_hiera_and_apply_on(host, remove_subfolders_hieradata, remove_manifest,
        { :catch_failures => true })
    end

    it 'should retain only untouched keys/folders in backends' do
      set_hiera_and_apply_on(host, verify_hieradata_after_subfolders_delete,
        verify_manifest, { :catch_failures => true })
    end

    it 'should call simpkv::deletetree with root folders without errors' do
      set_hiera_and_apply_on(host, remove_root_folders_hieradata,
        remove_manifest, { :catch_failures => true })
    end

    it 'should retain no key data in the backends' do
     # This makes sure there is no key data, but does not verify that the
     # directory tree is absent. That verification is done by the next test
     # example.
      expect( validator.call(initial_key_info, false, backend_hiera, host) ).to be true
    end

    it 'should retrieve non-existent or empty root dir list results from the backends' do
      # non-existent: Puppet environment root dirs
      # empty:        global root dirs
      set_hiera_and_apply_on(host, verify_empty_backend_folders_hieradata,
        verify_manifest, { :catch_failures => true })
    end

    it 'should call simpkv::deletetree with invalid folders without errors' do
      set_hiera_and_apply_on(host, remove_subfolders_hieradata,
        remove_manifest, { :catch_failures => true })
    end
  end
end

