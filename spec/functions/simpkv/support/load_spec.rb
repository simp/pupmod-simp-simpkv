require 'spec_helper'

describe 'simpkv::support::load' do
  it 'adds simpkv accessors to catalog instance at global scope when none exists' do
    is_expected.to run.with_params

    expect(catalogue.respond_to?(:simpkv)).to be true
    expect(catalogue.respond_to?(:simpkv=)).to be true
    [ :delete,
      :deletetree,
      :exists,
      :get,
      :list,
      :put].each do |api_method|
      expect(catalogue.simpkv.respond_to?(api_method)).to be true
    end
  end

  it 'uses existing simpkv adapter instance when catalog has simpkv accessors' do
    is_expected.to run.with_params
    simpkv_class_id1 = catalogue.simpkv.to_s

    is_expected.to run.with_params
    simpkv_class_id2 = catalogue.simpkv.to_s

    expect(simpkv_class_id1).to eq simpkv_class_id2
  end

  it 'fails when simpkv.rb does not exist' do
    allow(File).to receive(:exist?).with(any_args).and_call_original
    allow(File).to receive(:exist?).with(%r{simpkv/loader.rb}).and_return(false)
    is_expected.to run.with_params.and_raise_error(LoadError, %r{simpkv Internal Error: unable to load .* File not found})
  end

  it 'fails when simpkv.rb is malformed Ruby' do
    allow(File).to receive(:read).with(any_args).and_call_original
    allow(File).to receive(:read).with(%r{simpkv/loader.rb}).and_return("if true\n")
    is_expected.to run.with_params.and_raise_error(LoadError, %r{simpkv Internal Error: unable to load .* syntax error})
  end
end
