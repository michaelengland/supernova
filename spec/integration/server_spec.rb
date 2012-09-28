require "spec_helper"
require "webmock/rspec"
require "supernova/solr/server"

describe "Server Integration Spec" do
  let(:url) { "http://localhost:8985/solr/supernova_test" }
  let(:server) { Supernova::Solr::Server.new(url) }

  before(:each) do
    WebMock.disable!
    server.truncate
    server.commit
  end

  it "returns the correct reponse" do
    response = server.select
    response.should be_kind_of(Hash)
    response.fetch("response").fetch("numFound").should == 0
  end

  it "allows async selects" do
    server.index_docs([
        { id: 1, type: "Person" },
        { id: 2, type: "Person" },
      ]
    )
    server.commit
    a = nil
    b = nil
    server.select_async(fq: "id: 1") do |response|
      a = response
    end
    server.select_async(fq: "id: 2") do |response|
      b = response
    end
    a.should be_nil
    b.should be_nil
    server.run
    a.fetch("response").fetch("docs").should == [{ "id" => "1", "type" => "Person" }]
    b.fetch("response").fetch("docs").should == [{ "id" => "2", "type" => "Person" }]
  end

  class MyLogger
    def info(message)
      logs << message
    end

    def logs
      @logs ||= []
    end
  end

  it "logs all calls" do
    logger = MyLogger.new
    Supernova.logger = logger
    server.select
    logger.logs.count.should == 1
    logger.logs.first.should include("SUPERNOVA SOLR REQUEST")
  end

  it "sends notifications" do
    runs = []
    requests = []
    ActiveSupport::Notifications.subscribe("solr.run") do |*args|
      runs << args
    end
    ActiveSupport::Notifications.subscribe("solr.request") do |*args|
      requests << args
    end
    server.select_async(fq: "id: 1") do |response|
    end
    server.select_async(fq: "id: 1") do |response|
    end

    server.run
    runs.count.should == 1
    runs.last.last.fetch(:requests_count).should == 2
    requests.count.should == 2
    payload = requests.last.last
    payload.fetch(:method).should == :get
    payload.fetch(:host).should be_kind_of(String)
    payload.fetch(:params).should == {:q=>"*:*", :wt=>"json", :fq=>"id: 1"}
  end
end