# Execute simpkv::put operations via simpkv_test::store_keys to pre-populate key
# stores in the configured backend plugin.
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
#
shared_examples 'pre-populate keystores' do |host|
  context "ensure keystores are pre-populated with initial keys on #{host}" do
    let(:hieradata) do
      backend_hiera.merge({
                            'simpkv_test::store_keys::key_info' => initial_key_info,
                          })
    end

    let(:manifest) { 'include simpkv_test::store_keys' }

    it 'removes all backend instance data' do
      on(host, clear_data_cmd, accept_all_exit_codes: true)
    end

    it 'stores keys' do
      set_hiera_and_apply_on(host, hieradata, manifest, { catch_failures: true })
    end
  end
end
