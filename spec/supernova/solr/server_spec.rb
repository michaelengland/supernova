require File.expand_path("../../../../spec/spec_helper", __FILE__)
require "webmock/rspec"
require "solr/server"

describe "Supernova::Solr::Server" do
	let(:url) { "http://path.to.solr:112" }

  describe "#initialize" do
    it "can be initialized" do
      Supernova::Solr::Server.new(url).url.should == url
    end

    it "strips the trailing slash" do
      Supernova::Solr::Server.new("http://path.to.solr:112/").url.should == "http://path.to.solr:112"
    end
  end

  

  describe "#core_names" do
    it "returns the correct array" do
      stub_request(:get, "http://path.to.solr:112/admin/cores?action=STATUS&wt=json")
        .to_return(:status => 200, :body => project_root.join("spec/fixtures/cores_status.json").read, :headers => {})
      Supernova::Solr::Server.core_names(url).should == %w(project_test supernova_test)
    end
  end
end