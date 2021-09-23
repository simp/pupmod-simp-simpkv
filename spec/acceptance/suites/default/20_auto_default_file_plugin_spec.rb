require 'spec_helper_acceptance'

test_name 'simpkv auto-default file plugin'

# This test will not configure any backend in hieradata, store a few
# keys and verify they go to the auto-default file backend.
#
# Because /var/simp exists, the auto-default file backend will
# store its data within /var/simp/simpkv/file/auto_file
#
describe 'simpkv auto-default file plugin' do
  let(:clean_data_cmd) { 'rm -rf /var/simp/simpkv/file' }

  # No backend configuration in hieradata
  let(:hieradata) {{ }}

  # Store a few keys so we can spot check that the keys are being stored
  # in the auto-default backend
  let(:manifest) {
    <<~EOS
      simpkv::put('key1', 'environment key value1')
      simpkv::put('global1', 'global key value 1', {'version' => 10}, {'global' => true})
    EOS
  }

  hosts.each do |host|
    context "without simpkv configuration on #{host}" do
      it 'should start with no backend data' do
        on(host, clean_data_cmd)
      end

      it 'should call simpkv::put with no errors' do
        set_hiera_and_apply_on(host, hieradata, manifest,
          {:catch_failures => true} )
      end

      it 'should store keys in auto-default backend' do
        [
          '/var/simp/simpkv/file/auto_default/environments/production/key1',
          '/var/simp/simpkv/file/auto_default/globals/global1'
        ].each do |file|
          expect( file_exists_on(host, file) ).to be true
        end
      end
    end
  end
end
