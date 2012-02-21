require 'spec_helper'
require "ostruct"

describe "Supernova::SolrCriteria" do
  let(:criteria) { Supernova::SolrCriteria.new }
  let(:docs) do
    [
      {"popularity"=>10, "location"=>"47,11", "text"=>"Hans Meyer", "id"=>"offers/1", "enabled"=>false, "user_id"=>1, "type"=>"Offer"}, 
      {"popularity"=>1, "location"=>"46.9981112912042,11.6587158814378", "text"=>"Marek Mintal", "id"=>"offers/2", "enabled"=>true, "user_id"=>2, "type"=>"Offer"}
    ]
  end
  let(:solr_response) do
    {
      "response"=>{"start"=>0, "docs"=>docs, "numFound"=>2}, "responseHeader"=>{"QTime"=>4, "params"=>{"fq"=>"type:Offer", "q"=>"*:*", "wt"=>"ruby"}, "status"=>0}
    }
  end
  
  describe "#where" do
    it "sets the correct simple filters" do
      criteria.where("a_i:10").to_params[:fq].should == ["a_i:10"]
    end
    
    it "combines multiple filters" do
      criteria.where("a_i:10").where(:a => 1).to_params[:fq].should == ["a_i:10", "a:1"]
    end
    
    it "combines multiple filters with mappings" do
      criteria.attribute_mapping(:title => { :type => :string }).where(:title => "some_title").to_params[:fq].should == ["title_s:some_title"]
    end
  end
  
  describe "#fq_from_with" do
    it "returns the correct filter for with ranges" do
      criteria.fq_from_with([:user_id => Range.new(10, 12)]).should == ["user_id:[10 TO 12]"]
    end
    
    it "returns the correct filter for nin" do
      criteria.fq_from_with([:user_id.nin => [1, 2]]).should == ["!(user_id:1 OR user_id:2)"]
    end
    
    it "returns the correct filter for in" do
      criteria.fq_from_with([:user_id.in => [1, 2]]).should == ["user_id:1 OR user_id:2"]
    end
    
    it "returns the correct filter for not queries" do
      criteria.fq_from_with([:user_id.not => nil]).should == ["user_id:[* TO *]"]
    end
  end
  
  describe "#fq_filter_for_key_and_value" do
    it "returns the correct statment for nil" do
      criteria.fq_filter_for_key_and_value(:user_id, nil).should == "!user_id:[* TO *]"
    end
    
    it "returns the correct conditon for single values" do
      criteria.fq_filter_for_key_and_value(:user_id, 1).should == "user_id:1"
    end
    
    it "returns the correct condition for ranges" do
      criteria.fq_filter_for_key_and_value(:user_id, 1..10).should == "user_id:[1 TO 10]"
    end
    
    it "returns the correct conditon for single dates" do
      criteria.fq_filter_for_key_and_value(:released_on, Date.new(1999, 1, 2)).should == "released_on:1999-01-02T00:00:00Z"
    end
    
    it "returns the correct condition for date ranges" do
      date1 = Date.new(1999, 1, 2)
      date2 = Date.new(1999, 2, 5)
      range = Range.new(date1, date2)
      criteria.fq_filter_for_key_and_value(:open_at, range).should == "open_at:[1999-01-02T00:00:00Z TO 1999-02-05T00:00:00Z]"
    end
  end
  
  describe "#convert_search_order" do
    it "returns a string" do
      criteria.convert_search_order("title asc").should == "title asc"
    end
    
    it "returns a complex string" do
      criteria.convert_search_order("title asc, name desc").should == "title asc,name desc"
    end
  end
  
  describe "#to_params" do
    it "returns a Hash" do
      criteria.to_params.should be_an_instance_of(Hash)
    end
    
    it "sets the correct filters" do
      criteria.with(:title => "Hans Maulwurf", :playings => 10).to_params[:fq].sort.should == ["playings:10", "title:Hans Maulwurf"]
    end
    
    it "allways includes some query" do
      criteria.with(:a => 1).to_params[:q].should == "*:*"
    end
    
    it "sets the order field" do
      criteria.order("title asc").to_params[:sort].should == "title asc"
    end
    
    it "allows more complex order fields" do
      criteria.order("title asc, name desc").to_params[:sort].should == "title asc,name desc"
    end
    
    it "adds raw fields when not able to extract asc or desc" do
      criteria.order("some_order_func, test asc").to_params[:sort].should == "some_order_func,test asc"
    end
    
    it "chains order statements" do
      criteria.order("name asc").order("title desc").to_params[:sort].should == "name asc,title desc"
    end
    
    it "uses a mapped field for order" do
      criteria.attribute_mapping(:title => { :type => :string }).order("title asc").to_params[:sort].should == "title_s asc"
    end
    
    it "allows multi mappings of order criteria when given in one string" do
      scope = criteria.attribute_mapping(:title => { :type => :string }, :visits => { :type => :integer })
      scope.order("title asc, visits desc").to_params[:sort].should == "title_s asc,visits_i desc"
    end
    
    it "allows multi mappings of order criteria when chained" do
      scope = criteria.attribute_mapping(:title => { :type => :string }, :visits => { :type => :integer })
      scope.order("title asc").order("visits desc").to_params[:sort].should == "title_s asc,visits_i desc"
    end
    
    %w(asc desc).each do |order|
      it "uses a mapped field for order even when #{order} is present" do
        criteria.attribute_mapping(:title => { :type => :string }).order("title #{order}").to_params[:sort].should == "title_s #{order}"
      end
    end
    
    it "sets search correct search query" do
      criteria.search("some query").to_params[:q].should == "(some query)"
    end
    
    it "joins the search terms with AND" do
      criteria.search("some", "query").to_params[:q].should == "(some) AND (query)"
    end
    
    # fix me: use type_s
    it "adds a filter on type when clazz set" do
      Supernova::SolrCriteria.new(Offer).to_params[:fq].should == ["type:#{Offer}"]
    end
    
    it "does not add a filter on type when clazz is nil" do
      criteria.to_params[:fq].should == []
    end
    
    it "sets the correct select filters when present" do
      criteria.select(:user_id).select(:user_id).select(:enabled).to_params[:fl].should == "user_id,enabled,id"
    end
    
    describe "with facet fields" do
      it "sets the correct facet options when set" do
        params = criteria.facet_fields(:name).to_params
        params[:facet].should == true
      end
    
      it "sets all facet fields" do
        params = criteria.facet_fields(:name).facet_fields(:title).to_params
        params["facet.field"].should == ["name", "title"]
      end
    end
    
    describe "with facet queries" do
      let(:params) { criteria.facet_queries(:a => "a", :b => "b").to_params }
      
      it "sets :facet to true" do
        params[:facet].should == true
      end
      
      it "sets the correct facet query field" do
        criteria.facet_queries(:a => "a", :b => "b")
        params["facet.query"].should == ["a", "b"]
      end
    end
    
    it "uses mapped fields for select" do
      mapping = {
        :user_id => { :type => :integer },
        :enabled => { :type => :boolean }
      }
      criteria.attribute_mapping(mapping).select(:user_id, :enabled).to_params[:fl].should == "user_id_i,enabled_b,id"
    end
    
    it "adds all without filters" do
      criteria.without(:user_id => 1).to_params[:fq].should == ["!user_id:1"]
      criteria.without(:user_id => 1).without(:user_id => 1).without(:user_id => 2).to_params[:fq].sort.should == ["!user_id:1", "!user_id:2"]
    end
    
    it "uses mapped fields for without" do
      criteria.attribute_mapping(:user_id => { :type => :integer }).without(:user_id => 1).to_params[:fq].should == ["!user_id_i:1"]
    end
    
    describe "bounding box search" do
      it "includes the correct filter" do
        ne = double("ne", :lat => 48.0, :lng => 12.0)
        sw = double("sw", :lat => 47.0, :lng => 11.0)
        bounding_box = double("bbox", :ne => ne, :sw => sw)
        criteria.where(:pt.in => bounding_box).to_params[:fq].should include("pt:[47.0,11.0 TO 48.0,12.0]")
      end
    end
    
    describe "with a nearby search" do
      let(:nearby_criteria) { Supernova::SolrCriteria.new.near(47, 11).within(10.kms) }
      
      it "sets the correct center" do
        nearby_criteria.to_params[:pt].should == "47.0,11.0"
      end
      
      it "sets the correct distance" do
        nearby_criteria.to_params[:d].should == 10.0
      end
      
      it "sets the sfield to location" do
        nearby_criteria.to_params[:sfield].should == "location"
      end
      
      it "uses the mapped field when mapping defined" do
        nearby_criteria.attribute_mapping(:location => { :type => :location }).to_params[:sfield].should == "location_p"
      end
      
      it "sets the fq field to {!geofilt}" do
        nearby_criteria.to_params[:fq].should == ["{!geofilt}"]
      end
    end
    
    describe "setting rows and start" do
      it "allows setting of rows" do
        criteria.rows(11).to_params[:rows].should == 11
      end
      
      it "allows setting of start" do
        criteria.start(16).to_params[:start].should == 16
      end
      
      it "overwrites pagination with rows" do
        criteria.paginate(:per_page => 9, :page => 1).rows(11).to_params[:rows].should == 11
      end
      
      it "overwrites pagination with start" do
        criteria.paginate(:per_page => 9, :page => 1).start(100).rows(11).to_params[:start].should == 100
      end
    end
    
    describe "pagination" do
      it "sets the correct rows" do
        criteria.paginate(:page => 1, :per_page => 10).to_params[:rows].should == 10
      end
      
      it "sets the correct start when page is nil" do
        criteria.paginate(:per_page => 10).to_params[:start].should == 0
      end
      
      it "sets the correct start when page is 1" do
        criteria.paginate(:per_page => 10, :page => 1).to_params[:start].should == 0
      end
      
      it "sets the correct start when page is 1" do
        criteria.paginate(:per_page => 10, :page => 2).to_params[:start].should == 10
      end
    end
    
    describe "with attribute mapping" do
      it "uses the mapped fields" do
        criteria.attribute_mapping(:artist_name => { :type => :string }).where(:artist_name => "test").to_params[:fq].should == ["artist_name_s:test"]
      end
      
      it "accepts arrays as filters in where" do
        criteria.attribute_mapping(:artist_name => { :type => :string }).where(:artist_name => %w(hans maulwurf)).to_params[:fq].should == ["artist_name_s:hans", "artist_name_s:maulwurf"]
      end
      
      it "uses the mapped fields for all criteria queries" do
        criteria.attribute_mapping(:artist_name => { :type => :string }).where(:artist_name.ne => nil).to_params[:fq].should == ["artist_name_s:[* TO *]"]
      end
      
      it "uses the column when no mapping defined" do
        criteria.where(:artist_name => "test").to_params[:fq].should == ["artist_name:test"]
      end
    end
  end
  
  describe "#solr_field_from_field" do
    it "returns the field when no mappings defined" do
      criteria.solr_field_from_field(:artist_name).should == "artist_name"
    end
    
    it "returns the mapped field when mapping found" do
      criteria.attribute_mapping(:artist_name => { :type => :string }).solr_field_from_field(:artist_name).should == "artist_name_s"
    end
  end
  
  describe "#ids" do
    let(:response) { Supernova::Collection.new(1, 1, 100) }
    
    before(:each) do
      response.original_response = facet_response
    end
    
    it "sets the select fields to id only" do
      scope = double("scope")
      criteria.should_receive(:only_ids).and_return(scope)
      scope.should_receive(:execute).and_return(response)
      criteria.ids.should == [1, 2]
    end
    
    it "calls execute" do
      criteria.should_receive(:execute).and_return(response)
      criteria.ids
    end
    
    it "maps the id hashes to ids" do
      criteria.stub(:execute).and_return(response)
      criteria.ids.should == [1, 2]
    end
  end
  
  describe "#format" do
    it "sets the correct search_options" do
      criteria.format("csv").search_options[:wt].should == "csv"
    end
    
    it "includes the format in the params" do
      criteria.format("csv").to_params[:wt].should == "csv"
    end
    
    it "allows overriding of formats" do
      criteria.format("csv").format("json").to_params[:wt].should == "json"
    end
  end
  
  describe "#only_ids" do
    it "returns a criteria" do
      criteria.only_ids.should be_kind_of(Supernova::SolrCriteria)
    end
    
    it "only selects the id column" do
      a = criteria.select("name_s").only_ids
      a.to_params[:fl].should == "id"
    end
  end

  describe "#execute" do
    let(:params) { {} }
    let(:response) { double("response", :body => solr_response.to_json) }
    
    before(:each) do
      criteria.stub(:typhoeus_response).and_return(response)
      criteria.stub(:to_params).and_return params
    end
    
    it "sets the original response" do
      criteria.execute.original_response.should == solr_response
    end
    
    it "calls to_params" do
      criteria.should_receive(:typhoeus_response).and_return response
      criteria.execute
    end
    
    it "returns a Supernova::Collection" do
      criteria.execute.should be_an_instance_of(Supernova::Collection)
    end
    
    it "sets the correct page when page is nil" do
      criteria.execute.current_page.should == 1
    end
    
    it "sets the correct page when page is 1" do
      criteria.paginate(:page => 1).execute.current_page.should == 1
    end
    
    it "sets the correct page when page is 2" do
      criteria.paginate(:page => 2).execute.current_page.should == 2
    end
    
    it "sets the correct per_page when zero" do
      criteria.paginate(:page => 2, :per_page => nil).execute.per_page.should == 25
    end
    
    it "sets the custom per_page when given" do
      criteria.paginate(:page => 2, :per_page => 10).execute.per_page.should == 10
    end
    
    it "sets the correct total_entries" do
      criteria.paginate(:page => 2, :per_page => 10).execute.total_entries.should == 2
    end
    
    it "calls build_docs with returned docs" do
      criteria.should_receive(:build_docs).with(docs).and_return []
      criteria.execute
    end
    
    it "calls replace on collection with returned docs" do
      col = Supernova::Collection.new(1, 1, 10)
      Supernova::Collection.stub!(:new).and_return col
      built_docs = double("built docs")
      criteria.stub!(:build_docs).and_return built_docs
      col.should_receive(:replace).with(built_docs)
      criteria.execute
    end
    
    it "sets the correct facets" do
      response.stub!(:body).and_return(facet_response.to_json)
      criteria.should_receive(:hashify_facets_from_response).with(facet_response).and_return({ :a => 1 })
      criteria.execute.facets.should == {:a => 1}
    end
  end
  
  describe "#typhoeus_response" do
    it "returns the response" do
      response = double("response")
      request = double("request", :response => response)
      Typhoeus::Hydra.hydra.should_receive(:queue).with(request)
      Typhoeus::Hydra.hydra.should_receive(:run)
      criteria.stub!(:typhoeus_request).and_return(request)
      criteria.typhoeus_response.should == response
    end
  end
  
  describe "#execute_async" do
    let(:request) { double("request") }
    let(:response) { double("response", :body => solr_response.to_json) }
    let(:hydra) { double("hydra", :queue => nil) }
    
    before(:each) do
      request.should_receive(:on_complete).and_yield(response)
      criteria.stub!(:typhoeus_request).and_return(request)
      criteria.stub!(:hydra).and_return(hydra)
    end
    
    it "yields the parsed collection" do
      criteria.execute_async do |collection|
        @collection = collection
      end
      @collection.should be_kind_of(Supernova::Collection)
    end
    
    it "adds the request to hydra" do
      hydra.should_receive(:queue).with(request)
      criteria.execute_async do |collection|
        collection
      end
    end
  end
  
  it "returns the parsed response body" do
    response = double("response", :body => facet_response.to_json)
    criteria.stub!(:typhoeus_response).and_return(response)
    criteria.execute.original_response.should == facet_response
  end
  
  describe "#typhoeus_request" do
    it "returns a Typhoeus::Request" do
      criteria.typhoeus_request.should be_kind_of(Typhoeus::Request)
    end
    
    it "sets the correct url" do
      Supernova::Solr.stub(:select_url).and_return("my_select_url")
      criteria.typhoeus_request.url.should == "my_select_url?q=%2A%3A%2A&wt=json"
    end
    
    it "returns the correct params" do
      criteria.stub(:to_params).and_return(:a => 1)
      criteria.typhoeus_request.params.should == { :a => 1, :wt => "json"}
    end
    
    it "returns the correct request methods" do
      criteria.typhoeus_request.method.should == :get
    end
  end
  
  let(:facet_response) {
    {
      "response"=>{"start"=>0, "docs"=>[{"popularity_i"=>10, "enabled_b"=>false, "id"=>"offers/1", "user_id_i"=>1, "text_t"=>"Hans Meyer", "type"=>"Offer", "location_p"=>"47,11"}, {"popularity_i"=>1, "enabled_b"=>true, "id"=>"offers/2", "user_id_i"=>2, "text_t"=>"Marek Mintal", "type"=>"Offer", "location_p"=>"46.9981112912042,11.6587158814378"}], "numFound"=>2}, "facet_counts"=>{"facet_fields"=>{"text_t"=>["han", 1, "marek", 1, "meyer", 1, "mintal", 1]}, "facet_ranges"=>{}, "facet_dates"=>{}, "facet_queries"=>{}}, "responseHeader"=>{"QTime"=>4, "params"=>{"fq"=>"type:Offer", "facet.field"=>"text_t", "facet"=>"true", "q"=>"*:*", "wt"=>"ruby"}, "status"=>0}
    }
  }
  
  describe "#hashify_facets_from_response" do
    it "returns nil when nothing found" do
      criteria.hashify_facets_from_response({}).should == nil
    end
    
    it "returns the correct hash when facets returned" do
      criteria.hashify_facets_from_response(facet_response).should == {
        "text_t" => { "han" => 1, "marek" => 1, "meyer" => 1, "mintal" => 1 }
      }
    end
  end
  
  describe "#build_docs" do
    it "returns an array" do
      criteria.build_docs([]).should == []
    end
    
    it "returns the correct amount of docs" do
      criteria.build_docs(docs).length.should == 2
    end
    
    it "returns the correct classes" do
      docs = [ { "id" => "hosts/7", "type" => "Host" }, { "id" => "offers/1", "type" => "Offer" }]
      criteria.build_docs(docs).map(&:class).should == [Host, Offer]
    end
    
    it "calls build_doc on all returnd docs" do
      doc1 = double("doc1")
      doc2 = double("doc2")
      docs = [doc1, doc2]
      criteria.should_receive(:build_doc).with(doc1)
      criteria.should_receive(:build_doc).with(doc2)
      criteria.build_docs(docs)
    end
    
    it "uses a custom mapper when build_doc_method is set" do
      doc1 = { "a" => 1 }
      meth = lambda { |row| row.to_a }
      criteria.build_doc_method(meth).build_docs([doc1]).should == [[["a", 1]]]
    end
  end
  
  describe "#build_doc" do
    class OfferIndex < Supernova::SolrIndexer
      has :enabled, :type => :boolean
      has :popularity, :type => :integer
      has :is_deleted, :type => :boolean, :virtual => true
      clazz Offer
    end
    
    
    { "Offer" => Offer, "Host" => Host }.each do |type, clazz|
      it "returns the #{clazz} for #{type.inspect}" do
        criteria.build_doc("type" => type).should be_an_instance_of(clazz)
      end
    end
    
    it "calls convert_doc_attributes" do
      row = { "type" => "Offer", "id" => "offers/1" }
      criteria.should_receive(:convert_doc_attributes).with(row).and_return row
      criteria.build_doc(row)
    end
    
    it "returns the original hash when no type given" do
      type = double("type")
      row = { "id" => "offers/1", "type" => type }
      type.should_receive(:respond_to?).with(:constantize).and_return false
      criteria.should_not_receive(:convert_doc_attributes)
      criteria.build_doc(row).should == row
    end
    
    it "assigns the attributes returned from convert_doc_attributes to attributes when record responds to attributes=" do
      atts = { :title => "Hello" }
      row = { "type" => "Offer" }
      criteria.should_receive(:convert_doc_attributes).with(row).and_return atts
      doc = criteria.build_doc(row)
      doc.instance_variable_get("@attributes").should == atts
    end
    
    it "sets the original original_search_doc" do
      original_search_doc = { "type" => "Offer", "id" => "offers/id" }
      criteria.build_doc(original_search_doc).instance_variable_get("@original_search_doc").should == original_search_doc
    end
    
    it "should be readonly" do
      criteria.build_doc(docs.first).should be_readonly
    end
    
    it "should not be a new record" do
      criteria.build_doc(docs.first).should_not be_a_new_record
    end
    
    it "returns an offer and sets all given parameters" do
      criteria.attribute_mapping(:enabled => { :type => :boolean }, :popularity => { :type => :integer })
      doc = criteria.build_doc("type" => "Offer", "id" => "offers/1", "enabled_b" => true, "popularity_i" => 10)
      doc.should be_an_instance_of(Offer)
      doc.popularity.should == 10
    end
    
    it "sets selected parameters even when nil" do
      doc = criteria.select(:enabled, :popularity).build_doc("type" => "Offer", "id" => "offers/1")
      doc.enabled.should be_nil
      doc.popularity.should be_nil
    end
    
    it "it sets parameters to nil when no select given and not present" do
      doc = OfferIndex.search_scope.build_doc("type" => "Offer", "id" => "offers/1")
      doc.should be_an_instance_of(Offer)
      doc.popularity.should be_nil
    end
    
    it "does not set virtual parameters to nil" do
      OfferIndex.search_scope.build_doc("type" => "Offer", "id" => "offers/1").attributes.should_not have_key(:is_deleted)
      OfferIndex.search_scope.build_doc("type" => "Offer", "id" => "offers/1").attributes.should_not have_key("is_deleted")
    end
  end
  
  describe "#select_fields" do
    it "returns the fields from search_options when defined" do
      criteria.select(:enabled).select_fields.should == [:enabled]
    end
    
    it "returns the select_fields from named_search_scope when assigned and responding to" do
      fields = double("fields")
      nsc = double("scope", :select_fields => fields)
      criteria.named_scope_class(nsc)
      criteria.select_fields.should == fields
    end
    
    it "returns an empty array by default" do
      criteria.select_fields.should be_empty
    end
  end
  
  describe "#convert_doc_attributes" do
    { "popularity" => 10, "enabled" => false, "id" => "1" }.each do |key, value|
      it "sets #{key} to #{value}" do
        criteria.convert_doc_attributes("type" => "Offer", "some_other" => "Test", "id" => "offers/1", "enabled" => false, "popularity" => 10)[key].should == value
      end
    end
    
    { "popularity" => 10, "enabled" => true, "id" => "1" }.each do |field, value|
      it "uses sets #{field} to #{value}" do
        criteria.attribute_mapping(:enabled => { :type => :boolean }, :popularity => { :type => :integer })
        criteria.convert_doc_attributes("type" => "Offer", "id" => "offers/1", "enabled_b" => true, "popularity_i" => 10)[field].should == value
      end
    end
  
    
    class MongoOffer
      attr_accessor :id
    end
    
    it "would also work with mongoid ids" do
      criteria.convert_doc_attributes("type" => "MongoOffer", "id" => "offers/4df08c30f3b0a72e7c227a55")["id"].should == "4df08c30f3b0a72e7c227a55"
    end
  end
  
  describe "#reverse_lookup_solr_field" do
    it "returns the key when no mapping found" do
      Supernova::SolrCriteria.new.reverse_lookup_solr_field(:artist_id_s).should == :artist_id_s
    end
    
    it "returns the correct original key when mapped" do
      criteria.attribute_mapping(:artist_name => { :type => :string }).reverse_lookup_solr_field(:artist_name_s).should == :artist_name
    end
  end
  
  describe "#set_first_responding_attribute" do
    it "sets the reverse looked up attribute when found" do
      doc = OpenStruct.new(:artist_name => nil)
      criteria.attribute_mapping(:artist_name => { :type => :string }).set_first_responding_attribute(doc, :artist_name_s, "Mos Def")
      doc.artist_name.should == "Mos Def"
    end
    
    it "sets the original key when no mapping defined" do
      doc = OpenStruct.new(:artist_name_s => nil)
      criteria.attribute_mapping(:artist_name => { :type => :string }).set_first_responding_attribute(doc, :artist_name_s, "Mos Def")
      doc.artist_name_s.should == "Mos Def"
    end
    
    it "does not break on unknown keys" do
      doc = double("dummy")
      criteria.attribute_mapping(:artist_name => { :type => :string }).set_first_responding_attribute(doc, :artist_name_s, "Mos Def")
    end
  end
  
  describe "#current_page" do
    it "returns 1 when pagiantion is not set" do
      criteria.current_page.should == 1
    end
    
    it "returns 1 when page is set to nil" do
      criteria.paginate(:page => nil).current_page.should == 1
    end
    
    it "returns 1 when page is set to nil" do
      criteria.paginate(:page => 1).current_page.should == 1
    end
    
    it "returns 1 when page is set to nil" do
      criteria.paginate(:page => 0).current_page.should == 1
    end
    
    it "returns 2 when page is set to 2" do
      criteria.paginate(:page => 2).current_page.should == 2
    end
  end
  
  describe "#per_page" do
    it "returns 25 when nothing set" do
      criteria.per_page.should == 25
    end
    
    it "returns 25 when set to nil" do
      criteria.paginate(:page => 3, :per_page => nil).per_page.should == 25
    end
    
    it "returns 0 when set to 0" do
      criteria.paginate(:page => 3, :per_page => 0).per_page.should == 0
    end
    
    it "returns the custom value when set" do
      criteria.paginate(:page => 3, :per_page => 10).per_page.should == 10
    end
  end
end
