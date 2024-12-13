require 'spec_helper_acceptance'

test_name 'simpkv file plugin setup'

describe 'simpkv file plugin setup' do
  # Ensure /var/simp/simpkv already exists
  let(:manifest) do
    <<~EOM
      file {'/var/simp': ensure => directory }
      file {'/var/simp/simpkv': ensure => directory }
    EOM
  end

  hosts.each do |host|
    it "creates /var/simp/simpkv on #{host}" do
      apply_manifest_on(host, manifest, catch_failures: true)
    end
  end
end
