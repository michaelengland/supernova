require "spec_helper"
require "webmock/rspec"
require "solr/server"

describe "Supernova::Solr::Server" do
  let(:url) { "http://path.to.solr:112" }
  let(:server) { Supernova::Solr::Server.new(url) }
  

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
      server.core_names.should == %w(project_test supernova_test)
    end
  end

  describe "index_docs" do
    it "indexes the correct rows" do
      rows = [
        { "id" => 1, "title_s" => "Peter" },
        { "id" => 2, "title_s" => "Thomas" },
      ]
      stub_request(:post, "http://path.to.solr:112/update/json")
        .with(
          :body => "{\"add\":{\"doc\":{\"id\":1,\"title_s\":\"Peter\"}}}\n{\"add\":{\"doc\":{\"id\":2,\"title_s\":\"Thomas\"}}}",
          :headers => {'Content-Type'=>'application/json'}
        )
        .to_return(:status => 200, :body => "", :headers => {})
      server.index_docs(rows)
    end

    it "indexes the correct rows with commit" do
      rows = [
        { "id" => 1, "title_s" => "Peter" },
        { "id" => 2, "title_s" => "Thomas" },
      ]
      stub_request(:post, "http://path.to.solr:112/update/json?commit=true")
        .with(
          :body => "{\"add\":{\"doc\":{\"id\":1,\"title_s\":\"Peter\"}}}\n{\"add\":{\"doc\":{\"id\":2,\"title_s\":\"Thomas\"}}}",
          :headers => {'Content-Type'=>'application/json'}
        )
        .to_return(:status => 200, :body => "", :headers => {})
      server.index_docs(rows, true)
    end

    it "indexes the correct rows with commitWithin" do
      rows = [
        { "id" => 1, "title_s" => "Peter" },
        { "id" => 2, "title_s" => "Thomas" },
      ]
      stub_request(:post, "http://path.to.solr:112/update/json?commitWithin=10000")
        .with(
          :body => "{\"add\":{\"doc\":{\"id\":1,\"title_s\":\"Peter\"}}}\n{\"add\":{\"doc\":{\"id\":2,\"title_s\":\"Thomas\"}}}",
          :headers => {'Content-Type'=>'application/json'}
        )
        .to_return(:status => 200, :body => "", :headers => {})
      server.index_docs(rows, 10_000)
    end
  end

  it "selects with default parameter" do
    body = { "a" => 1 }.to_json
    stub_request(:get, "http://path.to.solr:112/select?q=*:*&wt=json")
      .to_return(:status => 200, :body => body, :headers => {})
    server.select.should == { "a" => 1 }
  end

  it "calls the commit statement" do
    stub_request(:post, "http://path.to.solr:112/my_name/update/json")
      .with(:body => "{\"commit\":{}}", :headers => {'Content-Type'=>'application/json'})
      .to_return(:status => 200, :body => "", :headers => {})
    core = Supernova::Solr::Server.new("#{url}/my_name")
    core.url.should == "#{url}/my_name"
    core.commit
  end

  it "calls the optimize statement" do
    stub_request(:post, "http://path.to.solr:112/update/json")
      .with(:body => "{\"optimize\":{}}", :headers => {'Content-Type'=>'application/json'})
      .to_return(:status => 200, :body => "", :headers => {})
    server.optimize
  end

  describe "#delete" do
    it "deletes by query" do
      stub_request(:post, "http://path.to.solr:112/update/json")
        .with(:body => "{\"delete\":{\"query\":\"id:1\"}}", :headers => {'Content-Type'=>'application/json'})
        .to_return(:status => 200, :body => "", :headers => {})
      server.delete_by_query("id:1")
    end

    it "truncates the index" do
      stub_request(:post, "http://path.to.solr:112/update/json?commit=true")
        .with(:body => "{\"delete\":{\"query\":\"*:*\"}}", :headers => {'Content-Type'=>'application/json'})
        .to_return(:status => 200, :body => "", :headers => {})
      server.truncate(true)
    end
  end
end
