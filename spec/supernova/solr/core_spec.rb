require File.expand_path("../../../../spec/spec_helper", __FILE__)
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

  describe "index_docs" do
    it "indexes the correct rows" do
      rows = [
        { "id" => 1, "title_s" => "Peter" },
        { "id" => 2, "title_s" => "Thomas" },
      ]
      url = "http://path.to.solr:1122/solr/my_core"
      stub_request(:post, "http://path.to.solr:1122/solr/my_core/update/json")
        .with(
          :body => "{\"add\":{\"doc\":{\"id\":1,\"title_s\":\"Peter\"}}}\n{\"add\":{\"doc\":{\"id\":2,\"title_s\":\"Thomas\"}}}",
          :headers => {'Content-Type'=>'application/json'}
        )
        .to_return(:status => 200, :body => "", :headers => {})
      Supernova::Solr::Core.index_docs(url, rows)
    end

    it "indexes the correct rows with commit" do
      rows = [
        { "id" => 1, "title_s" => "Peter" },
        { "id" => 2, "title_s" => "Thomas" },
      ]
      stub_request(:post, "http://path.to.solr:1122/solr/my_core/update/json?commit=true")
        .with(
          :body => "{\"add\":{\"doc\":{\"id\":1,\"title_s\":\"Peter\"}}}\n{\"add\":{\"doc\":{\"id\":2,\"title_s\":\"Thomas\"}}}",
          :headers => {'Content-Type'=>'application/json'}
        )
        .to_return(:status => 200, :body => "", :headers => {})
      Supernova::Solr::Core.index_docs(core_url, rows, true)
    end

    it "indexes the correct rows with commitWithin" do
      rows = [
        { "id" => 1, "title_s" => "Peter" },
        { "id" => 2, "title_s" => "Thomas" },
      ]
      stub_request(:post, "http://path.to.solr:1122/solr/my_core/update/json?commitWithin=10000")
        .with(
          :body => "{\"add\":{\"doc\":{\"id\":1,\"title_s\":\"Peter\"}}}\n{\"add\":{\"doc\":{\"id\":2,\"title_s\":\"Thomas\"}}}",
          :headers => {'Content-Type'=>'application/json'}
        )
        .to_return(:status => 200, :body => "", :headers => {})
      Supernova::Solr::Core.index_docs(core_url, rows, 10_000)
    end
  end

  describe "#delete" do
    it "deletes by query" do
      stub_request(:post, "http://path.to.solr:1122/solr/my_core/update/json")
        .with(:body => "{\"delete\":{\"query\":\"id:1\"}}", :headers => {'Content-Type'=>'application/json'})
        .to_return(:status => 200, :body => "", :headers => {})
      Supernova::Solr::Core.delete_by_query(core_url, "id:1")
    end

    it "truncates the index" do
      stub_request(:post, "http://path.to.solr:1122/solr/my_core/update/json?commit=true")
        .with(:body => "{\"delete\":{\"query\":\"*:*\"}}", :headers => {'Content-Type'=>'application/json'})
        .to_return(:status => 200, :body => "", :headers => {})
      Supernova::Solr::Core.truncate(core_url, true)
    end
  end

  describe "#select" do
    it "selects with default parameters" do
      stub_request(:get, "http://path.to.solr:1122/solr/my_core/select?q=*:*&wt=json")
        .to_return(:status => 200, :body => "", :headers => {})
      Supernova::Solr::Core.select(core_url)
    end
  end

  it "calls the commit statement" do
    stub_request(:post, "http://path.to.solr:1122/update/json")
      .with(:body => "{\"commit\":{}}", :headers => {'Content-Type'=>'application/json'})
      .to_return(:status => 200, :body => "", :headers => {})
    Supernova::Solr::Core.commit(url)
  end

  it "delegates commit for instance methods" do
    stub_request(:post, "http://path.to.solr:1122/my_name/update/json")
      .with(:body => "{\"commit\":{}}", :headers => {'Content-Type'=>'application/json'})
      .to_return(:status => 200, :body => "", :headers => {})
    core = Supernova::Solr::Core.new(url, "my_name")
    core.url.should == "#{url}/my_name"
    core.commit
  end

  it "calls the optimize statement" do
    stub_request(:post, "http://path.to.solr:1122/update/json")
      .with(:body => "{\"optimize\":{}}", :headers => {'Content-Type'=>'application/json'})
      .to_return(:status => 200, :body => "", :headers => {})
    Supernova::Solr::Core.optimize(url)
  end
end