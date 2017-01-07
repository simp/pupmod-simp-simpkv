#!/usr/bin/env ruby -S rspec
# vim: set expandtab ts=2 sw=2:
require 'spec_helper'
require 'pry'

valid_characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890/_-+'
invalid_characters = ";':,./<>?[]\{}|=`~!@#$%^&*()\""
describe 'libkv::atomic_put' do
  it 'should throw an exception with empty parameters' do
    is_expected.to run.with_params({}).and_raise_error(Exception);
  end
  providers.each do |providerinfo|
    provider = providerinfo["name"]
    url = providerinfo["url"]
    shared_params = {
      "url" => url
    }
    context "when provider = #{provider}" do
      def set_value(shared)
        call_function("libkv::put", shared.merge({"value" => "value3"}))
      end
      context "and when the key doesn't exist" do
        it 'should throw an exception' do
          params = {
            'key' => '/test/atomic_put/test1'
          }.merge(shared_params)
          is_expected.to run.with_params(params).and_raise_error(Exception);
	end
      end
      context "and when the key doesn't exist and previous is empty" do
        it 'should return true' do
          params = {
            'key' => '/test/atomic_put/test2'
          }.merge(shared_params)
          empty = call_function("libkv::empty_value", params)
          result = subject.execute(params.merge({'previous' => empty, 'value' => 'value2'}))
          expect(result).to eql(true)
        end
        it 'should set the key to value' do
          params = {
            'key' => '/test/atomic_put/test3'
          }.merge(shared_params)
          empty = call_function("libkv::empty_value", params)
          subject.execute(params.merge({'previous' => empty, 'value' => 'value3'}))
          result = call_function("libkv::get", params)
          expect(result).to eql("value3")
        end
      end
      context "and when the key doesn't exist and previous is random" do
        it 'should return false' do
          params = {
            'key' => '/test/atomic_put/test4'
          }.merge(shared_params)
          call_function("libkv::put", params.merge({'key' => '/test/atomic_put/test5', 'value' => 'value5'}))
          random = call_function("libkv::get", params.merge({'key' => '/test/atomic_put/test5'}))
          result = subject.execute(params.merge({'previous' => random, 'value' => 'value4'}))
          expect(result).to eql(false)
        end
        it 'should not set the key to value' do
          params = {
            'key' => '/test/atomic_put/test6'
          }.merge(shared_params)
          call_function("libkv::put", params.merge({'key' => '/test/atomic_put/test5', 'value' => 'value5'}))
          random = call_function("libkv::get", params.merge({'key' => '/test/atomic_put/test5'}))
          subject.execute(params.merge({'previous' => random, 'value' => 'value6'}))
          result = call_function("libkv::get", params)
          expect(result).to eql(nil)
        end
      end
    end
  end
end
