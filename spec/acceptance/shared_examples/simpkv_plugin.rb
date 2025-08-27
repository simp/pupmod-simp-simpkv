# Execute and verify simpkv functions using the configured backend plugin(s).
#
# TEST OVERVIEW
# This test uses the following:
# - A set of backend instances to verify app_id-based backend selection.
# - The simpkv_test module to exercise the simpkv::* functions and to verify
#   their operation, independent of the backend type used.
# - A backend-specific validator function provided by the plugin developer to
#   independently verify keys are present/absent in the appropriate backend.
# - Initial key data and methods to transform that data into hieradata for all
#   the simpkv_test manifests that affect key storage, removal, retrieval, and
#   validation.
#
# TEST STRUCTURE
# This test includes specific shared_examples for each simpkv function. These
# examples are written to be self contained. In other words, each included
# share_example resets the keystores to a known state before executing any
# tests. This makes the tests much easier to understand.
#
# VERIFICATION DETAILS:
# This test uses 2 types of verification:
# - API-self-consistency verification via the simpkv_test module.
#   - The simpkv_test module exclusively uses simpkv functions for
#     storage/retrieval operations.
#   - The simpkv_test module verifies the content of the retrieve operations:
#     - true/false returned values for existence checks of present/absent
#       keys and folders.
#     - Key value and metadata verification for existing keys
#     - Folder list contents for existing folders
#     - Null results for keys/folders that are expected to be absent, when
#       the 'softfail' simpkv option is used.
# - Backend-specific verification via a plugin-developer-provided validator
#   function.
#   - Validates data is stored appropriately when it is expected to be present.
#   - Validates data is not stored when it is expected to be absent.
#   - The only mechanism that ensures the data is stored where it is
#     supposed to be stored!
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
# NOTE FOR MAINTAINERS
# Before updating this test, please take time to understand what the simpkv_test
# module does and how the Acceptance::Helpers::TestData methods are used to
# drive that module to exercise and validate simpkv functions. To aid
# understanding and debug
# * Each time a simpkv_test manifest is used, the hieradata and manifest are
#   logged to the console.
# * The simpkv_test manifests log info-level, detailed messages to tell you
#   what is happening during a catalog complile. This includes when a simpkv
#   function is called, the parameters used in the function call, when results
#   from a simpkv retrieval operation are being compared with expected values,
#   and details about any comparison failures.
#
# @param host Host object on which the test manifests will be applied and
#   independent verification commands executed
#
shared_examples 'a simpkv plugin test' do |host|
  # This is a very high level, test configuration sanity check, but will not
  # detect all misconfiguration errors (especially ones that result in
  # non-unique keys, e.g., when multiple app_ids unexpectedly end up in the
  # same backend).
  #
  # Included examples may have more specific validation, especially WRT to
  # whether initial_key_info has appropriate data for derived data used to
  # stimulate the key/folder removal tests.
  it 'has basic test configuration' do
    expect(backend_hiera.key?('simpkv::options')).to be true
    expect(backend_hiera['simpkv::options'].key?('backends')).to be true
    expect(backend_hiera['simpkv::options']['backends'].key?('default')).to be true

    expect(initial_key_info).not_to be_empty
    initial_key_info.each_key do |app_id|
      appid = app_id.empty? ? 'default' : app_id
      expect(backend_hiera['simpkv::options']['backends'].keys.include?(appid)).to be true
    end
  end

  # All other simpkv function tests depend upon the keystores being populated
  # by simpkv::put via simpkv_test manifests. So, make sure the simpkv::put
  # operation is verified **first**.
  include_examples('simpkv::put tests', host)

  include_examples('simpkv::exists tests', host)
  include_examples('simpkv::get tests', host)
  include_examples('simpkv::list tests', host)

  # The simpkv::delete and simpkv::deletetree tests will use simpkv::get and
  # simpkv::list, respectively, as part of their removal verfication. So, make
  # sure these tests come **after** the simpkv:get and simpkv::list operations
  # are verified by their tests.
  include_examples('simpkv::delete tests', host)
  include_examples('simpkv::deletetree tests', host)
end
