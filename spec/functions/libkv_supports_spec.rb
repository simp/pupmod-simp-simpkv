#!/usr/bin/env ruby -S rspec
# vim: set expandtab ts=2 sw=2:
require 'spec_helper'
require 'pry'

valid_characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890/_-+'
invalid_characters = ";':,./<>?[]\{}|=`~!@#$%^&*()\""

describe 'libkv::supports', :type => :puppet_function do
  it 'should not throw an exception with empty parameters' do
    is_expected.not_to run.with_params().and_raise_error(Exception);
  end
  providers.each do |providerinfo|
    provider = providerinfo["name"]
    url = providerinfo["url"]
    auth = providerinfo["auth"]
    shared_params = {
      "url" => url,
      "auth" => auth,
    }
    context "when provider = #{provider}" do
      let(:params) do
        shared_params
      end

      it 'should return an array' do
        result = subject.execute({});
        expect(result.class).to eql(Array);
      end

      it 'should return an array of strings' do
        result = subject.execute({});
        expect(result[0].class).to eql(String);
      end

      expected_operations = [
        "delete",
        "deletetree",
        "get",
        "put",
        "exists",
        "list",

        "atomic_create",
        "atomic_delete",
        "atomic_get",
        "atomic_put",
        "atomic_list",

        "empty_value",
        "info",
        "provider",
        "supports",
      ]
      expected_operations.each do |operation|
        it "should return #{operation}" do
          result = subject.execute(params);
          expect(result.include?(operation)).to eql(true);
        end
      end
    end
  end
end

