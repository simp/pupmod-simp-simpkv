# Execute and verify simpkv::put using the configured backend plugins.
#
# ASSUMED CONTEXT:
# The following are assumed to be available within this shared_examples context:
# * `clear_data_cmd`:  Command string to be executed on the host to clear out
#   all stored key data in the configured backends.
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
# * `validator`:  Method object that can be called to independently validate
#   backend state:
#   - Method will be called to validate whether keys are present or absent in
#     their corresponding backends, and when they are expected to be present,
#     the stored key data is correct.
#   - Method must return a Boolean indicating validation success
#   - Method should log details of validation failures for debug
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
# @param host Host object on which the test manifests will be applied and
#   independent verification commands executed
#
shared_examples 'simpkv::put tests' do |host|
  context "ensure empty keystore(s) on #{host}" do
    it 'removes all backend instance data' do
      on(host, clear_data_cmd, accept_all_exit_codes: true)
    end
  end

  context "simpkv::put operation on #{host}" do
    let(:hieradata) do
      backend_hiera.merge({
                            'simpkv_test::store_keys::key_info' => initial_key_info
                          })
    end

    let(:updated_key_info) { modify_key_data(initial_key_info) }
    let(:updated_hieradata) do
      backend_hiera.merge({
                            'simpkv_test::store_keys::key_info' => updated_key_info
                          })
    end

    let(:manifest) { 'include simpkv_test::store_keys' }

    it 'calls simpkv::put without errors' do
      set_hiera_and_apply_on(host, hieradata, manifest, { catch_failures: true })
    end

    it 'stores the keys in the configured backends' do
      expect(validator.call(initial_key_info, true, backend_hiera, host)).to be true
    end

    it 'calls simpkv::put without errors when keys already exist with same value' do
      apply_manifest_on(host, manifest, catch_failures: true)
    end

    it 'retains the keys in the configured backends' do
      expect(validator.call(initial_key_info, true, backend_hiera, host)).to be true
    end

    it 'calls simpkv::put without errors when keys already exist with different values' do
      set_hiera_and_apply_on(host, updated_hieradata, manifest, { catch_failures: true })
    end

    it 'updates the keys in the configured backends' do
      expect(validator.call(updated_key_info, true, backend_hiera, host)).to be true
    end
  end
end
