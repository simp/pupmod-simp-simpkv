#!/usr/bin/env ruby -S rspec
# vim: set expandtab ts=2 sw=2:
require 'spec_helper'
require 'pry'

valid_characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890/_-+'
invalid_characters = ";':,./<>?[]\{}|=`~!@\#$%^&*()\""

describe 'libkv::put' do
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
      it 'should throw an exception when "key" is missing' do
        is_expected.to run.with_params(shared_params).and_raise_error(Exception)
      end
      it 'should throw an exception when "value" is missing' do
        is_expected.to run.with_params(shared_params.merge({"key" => "/test1"})).and_raise_error(Exception)
      end
      it 'should return a Boolean' do
        params = {
          'key' => '/test1',
          'value' => 'value1',
        }.merge(shared_params)
        result = subject.execute(params)
        expect(result.class).to eql(TrueClass)
      end
      datatype_testspec.each do |hash|
        it "should create an object of type #{hash[:class]} for /put/#{hash[:key]}" do
          params = {
             'key' => "/put/" + hash[:key],
             'value' => hash[:value],
          }.merge(shared_params)
          subject.execute(params)

          params = {
             'key' => "/put/" + hash[:key],
          }.merge(shared_params)
          result = call_function("libkv::get", params)
          expect(result.class).to eql(hash[:class])
        end
        it "should create the value '#{hash[:value]}' for /put/#{hash[:key]}" do
          params = {
             'key' => "/put/" + hash[:key],
             'value' => hash[:value],
          }.merge(shared_params)
          subject.execute(params)

          params = {
             'key' => "/put/" + hash[:key],
          }.merge(shared_params)
          result = call_function("libkv::get", params)
          expect(result).to eql(hash[:retval])
        end
      end
    end
  end
end
