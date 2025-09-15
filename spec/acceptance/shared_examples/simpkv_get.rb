# Execute and verify simpkv::get using the configured backend plugins.
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
shared_examples 'simpkv::get tests' do |host|
  include_examples('pre-populate keystores', host)

  context "simpkv::get operation on #{host}" do
    let(:hieradata_with_valid_keys) do
      backend_hiera.merge({
                            'simpkv_test::retrieve_and_verify_keys::valid_key_info'   => initial_key_info,
        'simpkv_test::retrieve_and_verify_keys::invalid_key_info' => {},
                          })
    end

    # copy of initial_key_info for which all key names have been modified
    let(:new_key_info) { rename_keys_in_key_info(initial_key_info) }

    let(:hieradata_with_invalid_keys) do
      backend_hiera.merge({
                            'simpkv_test::retrieve_and_verify_keys::valid_key_info'   => {},
        'simpkv_test::retrieve_and_verify_keys::invalid_key_info' => new_key_info,
                          })
    end

    let(:manifest) { 'include simpkv_test::retrieve_and_verify_keys' }

    it 'calls simpkv::get for valid keys without errors and verify retrieved info' do
      set_hieradata_on(host, hieradata_with_valid_keys)
      apply_manifest_on(host, manifest, catch_failures: true)
    end

    it 'calls simpkv::get with softfail=true for invalid keys without errors and verify nothing is retrieved' do
      set_hieradata_on(host, hieradata_with_invalid_keys)
      apply_manifest_on(host, manifest, catch_failures: true)
    end
  end
end
