require "spec_helper"
require "webmock/rspec"
require "solr/core"

describe "Supernova::Solr::Core" do
  let(:url) { "http://path.to.solr:1122" }
  let(:core_url) { "http://path.to.solr:1122/solr/my_core" }

  describe "#initialize" do
    it "can be initialized" do
      core = Supernova::Solr::Core.new(url, "my_name")
      core.solr_url.should == url
      core.name.should == "my_name"
    end

    it "removes trailing slashes for the solr_url" do
      Supernova::Solr::Core.new("http://path.to.solr:1122/solr/", "my_name").url.should == "http://path.to.solr:1122/solr/my_name"
    end
  end

  it "returns the correct url" do
    Supernova::Solr::Core.new(url, "my_name").url.should == "#{url}/my_name"
  end

  it "creates the correct core" do
    instance_path = "/path/to/instance"
    data_path = "/path/to/data"
    stub_request(:get, "http://path.to.solr:1122/admin/cores?action=CREATE&dataDir=/path/to/data&instanceDir=/path/to/instance&name=my_name&wt=json")
      .to_return(:status => 200, :body => "", :headers => {})
    Supernova::Solr::Core.create(url, "my_name", instance_path, data_path)
  end

  it "correctly queries for core status" do
    instance_path = "/path/to/instance"
    data_path = "/path/to/data"
    stub_request(:get, "http://path.to.solr:1122/admin/cores?action=STATUS&core=my_name&wt=json")
      .to_return(:status => 200, :body => "", :headers => {})
    Supernova::Solr::Core.status(url, "my_name")
  end

  it "unloads the correct core" do
    instance_path = "/path/to/instance"
    data_path = "/path/to/data"
    stub_request(:get, "http://path.to.solr:1122/admin/cores?action=UNLOAD&core=my_name&deleteIndex=true&wt=json")
    .to_return(:status => 200, :body => "", :headers => {})
    Supernova::Solr::Core.unload(url, "my_name")
  end

  it "delegates unload for instance methods" do
    instance_path = "/path/to/instance"
    data_path = "/path/to/data"
    stub_request(:get, "http://path.to.solr:1122/admin/cores?action=UNLOAD&core=my_name&deleteIndex=true&wt=json")
    .to_return(:status => 200, :body => "", :headers => {})
    Supernova::Solr::Core.new(url, "my_name").unload
  end
end
