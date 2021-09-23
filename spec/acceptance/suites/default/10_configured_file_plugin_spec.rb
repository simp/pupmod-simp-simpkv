require_relative 'validate_file_entries'
require 'spec_helper_acceptance'

test_name 'simpkv configured file plugin'

describe 'simpkv configured file plugin' do
  # Method object to validate key file entries in an file instance.
  # - Conforms to the API specified in 'a simpkv plugin test' shared_examples
  let(:validator) { method(:validate_file_entries) }

  # Command to run on the test host to clear out all stored key data.
  # - Since the file plugin has to be on the same host as the file keystore,
  #   a local filesystem command is appropriate.
  let(:clear_data_cmd) { 'rm -rf /var/simp/simpkv/file' }


  # The ids below are the backend/app_id names used in the test:
  # - One must be 'default' or simpkv::options validation will fail.
  # - 'a simpkv plugin test' shared_examples assumes there is a one-to-one
  #    mapping of the app_ids in the input key data to the backend names.
  #    Although simpkv supports fuzzy logic for that mapping, we set the
  #    backend names/app_ids to the same values, here, for simplicity. The
  #    fuzzy mapping logic is tested in the unit test.
  # - The input-data-generator currently supports exactly 3 app_ids.
  # - 'default' app_id is mapped to '' in the generated input key data, which, in
  #   turn causes simpkv functions to be called in the test manifests without
  #   an app_id set.  In other words, 'default' maps to the expected, normal
  #   usage of simpkv functions.
  #
  let(:id1) { 'default' }
  let(:id2) { 'custom' }
  let(:id3) { 'custom_snowflake' }

  # simpkv::options hieradata for 3 distinct backends, one of which must
  # be 'default'
  let(:backend_hiera) {
    backend_configs = {
      id1 => {
        'type'      => 'file',
        'root_path' => "/var/simp/simpkv/file/#{id1}"
      },
      id2 => {
        'type'      => 'file',
        'root_path' => "/var/simp/simpkv/file/#{id2}"
      },
      id3 => {
        'type'      => 'file',
        'root_path' => "/var/simp/simpkv/file/#{id3}"
      }
    }

    generate_backend_hiera(backend_configs)
  }

  # Hash of initial key information for the 3 test backends/app_ids.
  #
  # 'a simpkv plugin test' uses this data to test key storage operations
  # and then transform the data into subsets that it uses to test key/folder
  # existence, folder lists, and key and folder delete operations.
  let(:initial_key_info) {
    generate_initial_key_info(id1, id2, id3)
  }

  hosts.each do |host|
    context "configured simpkv file plugin on #{host}" do
      it_behaves_like 'a simpkv plugin test', host
    end
  end
end
