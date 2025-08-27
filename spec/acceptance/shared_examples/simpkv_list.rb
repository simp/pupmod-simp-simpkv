# Execute and verify simpkv::list using the configured backend plugins.
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
shared_examples 'simpkv::list tests' do |host|
  include_examples('pre-populate keystores', host)

  context "simpkv::list operation on #{host}" do
    let(:initial_folder_info) { to_folder_info(initial_key_info) }
    let(:hieradata_with_valid_folders) do
      backend_hiera.merge({
                            'simpkv_test::retrieve_and_verify_folders::valid_folder_info'   => initial_folder_info,
        'simpkv_test::retrieve_and_verify_folders::invalid_folder_info' => {}
                          })
    end

    # copy of initial_folder_info for which all folder names have been modified
    let(:new_folder_info) { rename_folders_in_folder_info(initial_folder_info) }
    let(:hieradata_with_invalid_folders) do
      backend_hiera.merge({
                            'simpkv_test::retrieve_and_verify_folders::valid_folder_info'   => {},
        'simpkv_test::retrieve_and_verify_folders::invalid_folder_info' => new_folder_info
                          })
    end

    let(:manifest) { 'include simpkv_test::retrieve_and_verify_folders' }

    it 'calls simpkv::list for valid folders without errors and verify retrieved info' do
      set_hiera_and_apply_on(host, hieradata_with_valid_folders, manifest,
        { catch_failures: true })
    end

    it 'calls simpkv::list with softfail=true for invalid folders without errors and verify nothing is retrieved' do
      set_hiera_and_apply_on(host, hieradata_with_invalid_folders, manifest,
        { catch_failures: true })
    end
  end
end
