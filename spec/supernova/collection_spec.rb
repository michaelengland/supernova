require "spec_helper"

describe "Supernova::Collection" do
  let(:col) { Supernova::Collection.new(1, 10, 100) }
  
  let(:original_response_with_facets) do
    {"responseHeader"=>{"status"=>0, "QTime"=>2, "params"=>{"facet"=>"true", "wt"=>"json", "facet.query"=>["popularity_i:[* TO 1]", "popularity_i:[* TO 10]", "popularity_i:[* TO 100]"], "fq"=>"type:Offer", "q"=>"*:*"}}, "response"=>{"numFound"=>3, "start"=>0, "docs"=>[{"id"=>"offers/1", "type"=>"Offer", "popularity_i"=>1}, {"id"=>"offers/2", "type"=>"Offer", "popularity_i"=>10}, {"id"=>"offers/3", "type"=>"Offer", "popularity_i"=>100}]}, "facet_counts"=>{"facet_queries"=>{"popularity_i:[* TO 1]"=>1, "popularity_i:[* TO 10]"=>2, "popularity_i:[* TO 100]"=>3}, "facet_fields"=>{}, "facet_dates"=>{}, "facet_ranges"=>{}}}
  end
    
  let(:original_response_without_facets) do
    {"responseHeader"=>{"status"=>0, "QTime"=>0, "params"=>{"wt"=>"json", "fq"=>"type:Offer", "q"=>"*:*"}}, "response"=>{"numFound"=>3, "start"=>0, "docs"=>[{"id"=>"offers/1", "type"=>"Offer", "popularity_i"=>1}, {"id"=>"offers/2", "type"=>"Offer", "popularity_i"=>10}, {"id"=>"offers/3", "type"=>"Offer", "popularity_i"=>100}]}}
  end
  
  describe "#raw_facet_queries" do
    it "returns the correct facet queries when found" do
      col.original_response = original_response_with_facets
      col.raw_facet_queries.should == { "popularity_i:[* TO 1]"=>1, "popularity_i:[* TO 10]"=>2, "popularity_i:[* TO 100]"=>3 }
    end
    
    it "returns an empty hash when facet_queries is empty" do
      col.original_response = original_response_without_facets
      col.raw_facet_queries.should == {}
    end
  end
  
  describe "#facet_queries" do
    it "returns the correct hash" do
      crit = Supernova::Criteria.facet_queries(:one => "popularity_i:[* TO 1]", :ten => "popularity_i:[* TO 10]", :hundred => "popularity_i:[* TO 100]")
      col.original_criteria = crit
      col.original_response = original_response_with_facets
      col.facet_queries.should == { :one => 1, :ten => 2, :hundred => 3 }
    end
  end
  
  describe "#original_facet_queries" do
    it "returns the correct hash when facet queries activated" do
      queries = { :one => "popularity_i:[* TO 1]", :ten => "popularity_i:[* TO 10]", :hundred => "popularity_i:[* TO 100]" }
      col.original_criteria = Supernova::Criteria.facet_queries(queries)
      col.original_facet_queries.should == queries
    end
    
    it "returns an empty hash when not defined" do
      col.original_criteria = Supernova::Criteria.new
      col.original_facet_queries.should == {}
    end
  end
  
  describe "#ids" do
    let(:col) { Supernova::Collection.new(1, 1, 100) }
    
    before(:each) do
      col.original_response = original_response_without_facets
    end
    
    it "returns an array" do
      col.ids.should be_kind_of(Supernova::Collection)
    end
    
    it "uses extract_ids_from_solr_hash with response" do
      col.original_response = "some response"
      col.should_receive(:extract_ids_from_solr_hash).with("some response").and_return("result")
      col.ids
      col.ids.should == "result"
    end
  end
  
  describe "#extract_ids_from_solr_hash" do
    let(:result) { col.extract_ids_from_solr_hash(original_response_without_facets) }
    
    it "returns an array" do
      result.should be_kind_of(Array)
    end
    
    it "returns the correct ids" do
      result.should == [1, 2, 3]
    end
  end
end