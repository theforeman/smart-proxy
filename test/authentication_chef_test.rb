require 'test_helper'
require 'webmock/test_unit'
require 'proxy/authentication'
require 'net/https'
require 'sinatra'

class AuthenticationChefTest < Test::Unit::TestCase

  def setup
    @chefauth = Proxy::Authentication::Chef.new

    #We set a few chef related settings
    SETTINGS.stubs(:chef_server_url).returns('https://chef.example.com')
    SETTINGS.stubs(:chef_smartproxy_clientname).returns('testnode1')
    SETTINGS.stubs(:chef_smartproxy_privatekey).returns('test/fixtures/authentication/testnode1.priv')


    testnode1_key_path = 'test/fixtures/authentication/testnode1'
    testnode2_key_path = 'test/fixtures/authentication/testnode2'
    testnode1_key = OpenSSL::PKey::RSA.new(File.read(testnode1_key_path+'.priv'))
    @testnode1_pubkey = testnode1_key.public_key.to_s.gsub("\n",'\n')
    testnode2_key = OpenSSL::PKey::RSA.new(File.read(testnode2_key_path+'.priv'))
    @testnode2_pubkey = testnode2_key.public_key.to_s.gsub("\n",'\n')

    #we sign with the testnode1 key
    @mybody = "ForemanRoxx"
    hash_body = Digest::SHA256.hexdigest(@mybody)
    @signature = Base64.encode64(testnode1_key.sign(OpenSSL::Digest::SHA256.new,hash_body)).gsub("\n",'')
  end

  def test_signing_and_checking_with_same_key_sould_work
    # We need to mock chef-server response
    response = '{"public_key":"'+@testnode1_pubkey+'","name":"testnode1","admin":false,"validator":false,"json_class":"Chef::ApiClient","chef_type":"client"}'
    stub_request(:get, 'https://chef.example.com/clients/testnode1').to_return(:body => response.to_s, :headers => {'content-type' => 'application/json'} )

    assert(@chefauth.verify_signature_request('testnode1',@signature,@mybody), "Signing and checking with same key should pass")
  end

  def test_signing_and_checking_with_2_different_keys_sould_not_work
    # We mock chef-server response but with a wrong publick key to make signature check fail
    response = '{"public_key":"'+@testnode2_pubkey+'","name":"testnode1","admin":false,"validator":false,"json_class":"Chef::ApiClient","chef_type":"client"}'
    stub_request(:get, 'https://chef.example.com/clients/testnode1').to_return(:body => response.to_s, :headers => {'content-type' => 'application/json'} )

    assert_equal(false,@chefauth.verify_signature_request('testnode1',@signature,@mybody), "Signing and checking with different keys should not pass")
  end

  def test_auth_disabled_should_always_success
    SETTINGS.stubs(:chef_authenticate_nodes).returns(false)
    s = StringIO.new('Hello')
    request = Sinatra::Request.new(env={'rack.input' => s})
    result = @chefauth.authenticated(request) do |content|
      true
    end

    assert(result)
  end

  def test_auth_enable_without_headers_should_raise_an_error
    SETTINGS.stubs(:chef_authenticate_nodes).returns(true)
    s = StringIO.new('Hello')
    request = Sinatra::Request.new(env={'rack.input' => s})
    begin
      result = @chefauth.authenticated(request) do |content|
        true
      end
    rescue Proxy::Error::Unauthorized => e
      assert(e.is_a? Proxy::Error::Unauthorized)
    end
    assert_equal(nil,result)
  end
end
