require 'spec_helper'

describe Supernova::Solr do
  before(:each) do
    Supernova::Solr.url = "http://some.host:12345/path/to/solr"
  end
  
  describe "#url=" do
    it "allows setting a solr url" do
      Supernova::Solr.url = "some url"
      Supernova::Solr.url.should == "some url"
    end
  end
  
  describe "truncate!" do
    it "sends the correct update request" do
      Typhoeus::Request.should_receive(:post).with("http://some.host:12345/path/to/solr/update", 
        :body => %(<?xml version="1.0" encoding="UTF-8"?><delete><query>*:*</query></delete>), :headers => { "Content-Type" => "text/xml"}
      )
      Supernova::Solr.truncate!
    end
  end
  
  describe "#commit!" do
    it "sends the correct update request" do
      Typhoeus::Request.should_receive(:post).with("http://some.host:12345/path/to/solr/update", 
        :body => %(<?xml version="1.0" encoding="UTF-8"?><commit />), :headers => { "Content-Type" => "text/xml"}
      )
      Supernova::Solr.commit!
    end
  end
end
