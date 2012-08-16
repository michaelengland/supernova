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
end
