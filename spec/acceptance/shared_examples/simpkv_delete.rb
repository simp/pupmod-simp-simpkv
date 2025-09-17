# Execute and verify simpkv::delete using the configured backend plugins.
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
shared_examples 'simpkv::delete tests' do |host|
  include_examples('pre-populate keystores', host)

  context "simpkv::delete operation on #{host}" do
    # Hash with two keys:
    # - :remove = Key info Hash of keys to remove
    # - :retain = Key info Hash of keys to retain
    #
    # Hashes are subsets of initial_key_info
    #
    let(:test_key_infos) do
      key_infos = split_key_info(initial_key_info, 2)

      if key_infos[0].empty? || key_infos[1].empty?
        raise('Unable to split the initial_key_info into two non-empty Hashes. Data provided is too sparse')
      end

      {
        remove: key_infos[0],
        retain: key_infos[1],
      }
    end

    let(:remove_manifest) { 'include simpkv_test::remove_keys' }
    let(:remove_hieradata) do
      backend_hiera.merge({
                            'simpkv_test::remove_keys::keyname_info' => to_keyname_info(test_key_infos[:remove]),
                          })
    end

    let(:verify_manifest) { 'include simpkv_test::retrieve_and_verify_keys' }
    let(:verify_hieradata) do
      backend_hiera.merge({
                            'simpkv_test::retrieve_and_verify_keys::valid_key_info' => test_key_infos[:retain],
        'simpkv_test::retrieve_and_verify_keys::invalid_key_info' => test_key_infos[:remove],
                          })
    end

    it 'calls simpkv::delete with valid keys without errors' do
      set_hiera_and_apply_on(host, remove_hieradata, remove_manifest,
        { catch_failures: true })
    end

    it 'retains only untouched keys in backends' do
      expect(validator.call(test_key_infos[:retain], true, backend_hiera, host)).to be true
      expect(validator.call(test_key_infos[:remove], false, backend_hiera, host)).to be true
    end

    it 'onlies be able to retrieve untouched keys via simpkv::get' do
      set_hiera_and_apply_on(host, verify_hieradata, verify_manifest,
        { catch_failures: true })
    end

    it 'calls simpkv::delete with invalid keys without errors' do
      set_hiera_and_apply_on(host, remove_hieradata, remove_manifest,
        { catch_failures: true })
    end
  end
end
