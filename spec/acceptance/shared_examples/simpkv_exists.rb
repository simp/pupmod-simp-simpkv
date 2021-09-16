# Execute and verify simpkv::exists using the configured backend plugins.
#
# ASSUMED CONTEXT:
# The following are assumed to be available within this shared_examples context:
# * `clear_data_cmd`:  Command string to be executed on the host to clear out
#   all stored key data in the configured backends:
#   - Must work from the host being tested, even when the keystore is not
#     co-resident.
#
# * `backend_hiera`: 'simpkv::options' hash specifying backend configuration
#
# * `initial_key_info`: Hash specifying key data to be initially stored in
#   the backends:
#   - Format corresponds to the Simpkv_test::KeyInfo type alias
#   - **Must** have app_ids that correspond to the backends named in
#     backend_hiera
#
shared_examples 'simpkv::exists tests' do |host|
  include_examples('pre-populate keystores', host)

  context "simpkv::exists operation for keys on #{host}" do
    let(:initial_keyname_info) { to_keyname_info(initial_key_info) }
    let(:hieradata_with_valid_keys) {
      backend_hiera.merge( {
        'simpkv_test::verify_keys_exist::valid_keyname_info'   => initial_keyname_info,
        'simpkv_test::verify_keys_exist::invalid_keyname_info' => {}
      } )
    }

    # copy of initial_key_info for which all key names have been modified
    let(:new_key_info) { rename_keys_in_key_info(initial_key_info) }
    let(:new_keyname_info) { to_keyname_info(new_key_info) }

    let(:hieradata_with_invalid_keys) {
      backend_hiera.merge( {
        'simpkv_test::verify_keys_exist::valid_keyname_info'   => {},
        'simpkv_test::verify_keys_exist::invalid_keyname_info' => new_keyname_info
      } )
    }

    let(:manifest) { 'include simpkv_test::verify_keys_exist' }

    it 'should call simpkv::exists for valid keys and return true' do
      set_hiera_and_apply_on(host, hieradata_with_valid_keys, manifest,
        { :catch_failures => true })
    end

    it 'should call simpkv::exists for invalid keys and return false' do
      set_hiera_and_apply_on(host, hieradata_with_invalid_keys, manifest,
        { :catch_failures => true })
    end
  end

  context "simpkv::exists operation for folders on #{host}" do
    let(:initial_foldername_info) { to_foldername_info(initial_key_info) }
    let(:hieradata_with_valid_folders) {
      backend_hiera.merge( {
        'simpkv_test::verify_folders_exist::valid_foldername_info'   => initial_foldername_info,
        'simpkv_test::verify_folders_exist::invalid_foldername_info' => {}
      } )
    }

    # copy of inital_foldername_info for which all folder names have been modified
    let(:new_foldername_info) { rename_folders_in_name_info(initial_foldername_info) }
    let(:hieradata_with_invalid_folders) {
      backend_hiera.merge( {
        'simpkv_test::verify_folders_exist::valid_foldername_info'   => {},
        'simpkv_test::verify_folders_exist::invalid_foldername_info' => new_foldername_info
      } )
    }

    let(:manifest) { 'include simpkv_test::verify_folders_exist' }

    it 'should call simpkv::exists for valid folders and return true' do
      set_hiera_and_apply_on(host, hieradata_with_valid_folders, manifest,
        { :catch_failures => true })
    end

    it 'should call simpkv::exists for invalid folders and return false' do
      set_hiera_and_apply_on(host, hieradata_with_invalid_folders, manifest,
        { :catch_failures => true })
    end
  end
end
