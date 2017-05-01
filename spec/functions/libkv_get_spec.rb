#!/usr/bin/env ruby -S rspec
# vim: set expandtab ts=2 sw=2:
require 'spec_helper'

valid_characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890/_-+'
invalid_characters = ";':,./<>?[]\{}|=`~!@\#$%^&*()\""

describe 'libkv::get' do
  it 'should throw an exception with empty parameters' do
    is_expected.to run.with_params({}).and_raise_error(Exception);
  end
  providers.each do |providerinfo|
    provider = providerinfo["name"]
    url = providerinfo["url"]
    auth = providerinfo["auth"]
    shared_params = {
      "url" => url,
      "serialize" => providerinfo["serialize"],
      "mode" => providerinfo["mode"],
      "auth" => auth,
    }
    context "when provider = #{provider}" do
      it 'should throw an exception when "key" is missing' do
        is_expected.to run.with_params(shared_params).and_raise_error(Exception);
      end
      it "should return nil if the key doesn't exist" do
        params = {
           'key' => '/puppet/get/testx',
        }.merge(shared_params)
        result = subject.execute(params)
        expect(result).to eql(nil)
      end

      datatype_testspec.each do |hash|
        it "should return an object of type #{hash[:nonserial_class]} for /get/#{hash[:key]}" do
          params = {
             'key' => "/get/" + hash[:key],
             'value' => hash[:value],
          }.merge(shared_params)
          call_function("libkv::put", params)

          params = {
             'key' => "/get/" + hash[:key],
          }.merge(shared_params)
          result = subject.execute(params)
          expect(result.class).to eql(hash[:nonserial_class])
        end
        it "should return '#{hash[:value]}' for /get/#{hash[:key]}" do
          params = {
             'key' => "/get/" + hash[:key],
             'value' => hash[:value],
          }.merge(shared_params)
          call_function("libkv::put", params)

          params = {
             'key' => "/get/" + hash[:key],
          }.merge(shared_params)
          result = subject.execute(params)
          expect(result).to eql(hash[:retval])
        end
      end

        # subject.execute(params)
        # result = call_function("libkv::get", shared_params.merge({"key" => "/test2"}))
        # expect(result).to eql("value2")

    end
  end
end
