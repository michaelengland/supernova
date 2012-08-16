# -*- encoding : utf-8 -*-
require "spec_helper_ar"
require "webmock/rspec"
require "supernova/solr/server"

describe "Solr" do
  let(:url) { SOLR_URL }
  let(:server) { Supernova::Solr::Server.new(url) }
  
  before(:each) do
    WebMock.disable!
    Supernova::Solr.url = url
    Supernova::Solr.instance_variable_set("@connection", nil)
    server.truncate
    Offer.criteria_class = Supernova::SolrCriteria
    root = Geokit::LatLng.new(47, 11)
    # endpoint = root.endpoint(90, 50, :units => :kms)
    e_lat = 46.9981112912042
    e_lng = 11.6587158814378
    server.index_docs(
      [
        :id => "1", :type => "Offer", :user_id_i => 1, :enabled_b => false, 
        :text_t => "Hans Meyer", :popularity_i => 10, 
        :location_p => "#{root.lat},#{root.lng}", :type => "Offer"
      ]
    )
    server.index_docs(
      [
        :id => "2", :user_id_i => 2, :enabled_b => true, :text_t => "Marek Mintal", 
        :popularity_i => 1, 
        :location_p => "#{e_lat},#{e_lng}", :type => "Offer"
      ]
    )
    server.commit
  end
  
  after(:each) do
    WebMock.enable!
    Supernova::Solr.url = nil
    Supernova::Solr.instance_variable_set("@connection", nil)
    Offer.criteria_class = Supernova::SolrCriteria
    Supernova.logger = nil
  end
  
  def new_criteria
    Offer.search_scope
  end

  class DummyLogger
    attr_accessor :logs

    def initialize
      self.logs = []
    end

    def info(*args)
      self.logs << args
    end
  end
  let(:logger) { DummyLogger.new }

  it "allows setting of the read_url" do
    Supernova::Solr.url = "base/url"
    Supernova::Solr.read_url = "read/url"
    Supernova::Solr.read_url.should == "read/url"
  end

  it "returns the default url for write_url" do
    Supernova::Solr.url = "base/url"
    Supernova::Solr.write_url.should == "base/url"
  end

  describe "logging" do
    before(:each) do
      Supernova.logger = logger
      server.truncate
      indexer = Supernova::SolrIndexer.new
      indexer.index_with_json_string([
          { :title_s => "Title1", :id => 1, :type => "Record" }, 
          { :title_s => "Title2", :id => 2, :type => "Record" } 
        ]
      )
    end
  end
  
  describe "#index_with_json_string" do
    it "indexes the correct rows" do
      server.truncate
      indexer = Supernova::SolrIndexer.new
      indexer.index_with_json_string([
          { :title_s => "Title1", :id => 1, :type => "Record" }, 
          { :title_s => "Title2", :id => 2, :type => "Record" } 
        ]
      )
      response = JSON.parse(Typhoeus::Request.post(Supernova::Solr.url + "/select", :params => { :q=>'*:*', :start=>0, :rows=>10, :sort => "id asc", :wt => "json" }).body)
      response["response"]["docs"].first.should == { "title_s" => "Title1", "id" => "1", "type" => "Record" }
      response["response"]["docs"].at(1).should == { "title_s" => "Title2", "id" => "2", "type" => "Record" }
    end
  end
  
  describe "#indexing" do
    before(:each) do
      server.truncate
      server.commit
    end
    
    class OfferIndex < Supernova::SolrIndexer
      has :user_id, :type => :integer
      has :popularity, :type => :integer
      
      def before_index(row)
        row["indexed_at_dt"] = Time.now.utc.iso8601
        row
      end
      
      clazz Offer
    end
    
    it "indexes all Offers without file" do
      offer1 = Offer.create!(:user_id => 1, :popularity => 10)
      offer2 = Offer.create!(:user_id => 2, :popularity => 20)
      indexer = OfferIndex.new(:db => ActiveRecord::Base.connection)
      indexer.index!
      OfferIndex.search_scope.first.fetch("indexed_at_dt").should_not be_nil
      OfferIndex.search_scope.total_entries.should == 2
      results = OfferIndex.search_scope.order("user_id desc").populate.results
      results.count.should == 2
      results.first.fetch("user_id_i").should == 2
      results.first.fetch("popularity_i").should == 20

      results.at(1).fetch("user_id_i").should == 1
      results.at(1).fetch("popularity_i").should == 10
    end
    
    it "indexes with a file" do
      offer1 = Offer.create!(:user_id => 1, :popularity => 10, id: 1)
      offer2 = Offer.create!(:user_id => 2, :popularity => 20, id: 2)
      indexer = OfferIndex.new(:db => ActiveRecord::Base.connection, :max_rows_to_direct_index => 0)
      indexer.options[:use_json_file] = true
      indexer.index!
      OfferIndex.search_scope.total_entries.should == 2
      OfferIndex.search_scope.first.fetch("indexed_at_dt").should_not be_nil
      OfferIndex.search_scope.order("user_id desc").populate.results.map { |row| row.fetch("id") }.should == %w(offers/2 offers/1)
    end
    
    describe "with extra_attributes_from_doc method defined" do
      class OfferIndexWitheExtraSearchMethodFromDoc < Supernova::SolrIndexer
        has :user_id, :type => :integer
        has :popularity, :type => :integer
        has :upcased_text, :type => :text, :virtual => true
        has :text, :type => :text
        
        clazz Offer
        
        def before_index(row)
          if text = row["text"]
            row["upcased_text"] = text.to_s.upcase.presence
          end
          row
        end
      end
      
      it "sets the capitalize_text attribute" do
        Offer.create!(:user_id => 2, :popularity => 20, :text => "lower_text")
        indexer = OfferIndexWitheExtraSearchMethodFromDoc.new(:db => ActiveRecord::Base.connection)
        indexer.index!
        offer = OfferIndexWitheExtraSearchMethodFromDoc.search_scope.first
        offer.fetch("upcased_text_t").should == "LOWER_TEXT"
      end
    end
  end
  
  describe "searching" do
    it "returns the correct current_page when nil" do
      new_criteria.current_page.should == 1
    end
    
    it "returns the correct page when set" do
      new_criteria.paginate(:page => 10).current_page.should == 10
    end
    
    it "the correct per_page when set" do
      new_criteria.paginate(:per_page => 10).per_page.should == 10
    end
    
    it "the correct per_page when not set" do
      new_criteria.per_page.should == 25
    end
    
    describe "plain text search" do
      it "returns the correct entries for 1 term" do
        new_criteria.search("text_t:Hans").map { |h| h["id"] }.should == %w(1)
        new_criteria.search("text_t:Hans").search("text_t:Meyer").map { |h| h["id"] }.should == %w(1)
        new_criteria.search("text_t:Marek").map { |h| h["id"] }.should == %w(2)
      end
      
      it "returns the correct options for a combined search" do
        new_criteria.search("text_t:Hans", "text_t:Marek").populate.results.should == []
      end
    end
    
    describe "nearby search" do
      { 49.kms => 1, 51.kms => 2 }.each do |distance, total_entries|
        it "returns #{total_entries} for distance #{distance}" do
          new_criteria.attribute_mapping(:location => { :type => :location }).near(47, 11).within(distance).total_entries.should == total_entries
        end
      end
    end
    
    describe "bounding box search" do
      class Coordinate
        attr_accessor :lat, :lng
        
        def initialize(attributes = {})
          attributes.each do |key, value|
            self.send(:"#{key}=", value)
          end
        end
        
        def to_s
          "#{lat},#{lng}"
        end
      end
      
      class BoundingBox
        attr_accessor :ne, :sw
        
        def initialize(attributes = {})
          attributes.each do |key, value|
            self.send(:"#{key}=", value)
          end
        end
      end
      
      let(:inside) { GeoKit::LatLng.new(9.990317, 53.556698) }
      let(:outside) { GeoKit::LatLng.new(9.987238, 53.555950) }
      
      let(:sw_lat) { 9.988139 }
      let(:sw_lng) { 53.556068 }
      let(:sw) { c = GeoKit::LatLng.new(sw_lat, sw_lng) }
      
      let(:ne_lat) { 9.992849 }
      let(:ne_lng) { 53.557522 }
      let(:ne) { GeoKit::LatLng.new(ne_lat, ne_lng) }
      
      let(:bounding_box) { GeoKit::Bounds.new(sw, ne) }
      
      
      before(:each) do
        server.truncate
        server.index_docs([:id => "1", :location_p => inside.to_s, :type => "Test"])
        server.index_docs([:id => "2", :location_p => outside.to_s, :type => "Test"])
        server.commit
      end
      
      it "the correct entries" do
        scope = Supernova::SolrCriteria.new.with(:location_p.in => bounding_box)
        scope.ids.should == [1]
      end
      
      it "includes the egdes" do
        Supernova::SolrCriteria.new.with(:location_p.in => GeoKit::Bounds.new(outside, inside)).ids.should == [1, 2]
      end
      
      it "includes the egdes" do
        Supernova::SolrCriteria.new.with(:location_p.inside => GeoKit::Bounds.new(outside, inside)).ids.should == []
      end
    end
    
    describe "range search" do
      { Range.new(2, 3) => %w(2), Range.new(3, 10) => [], Range.new(1, 2) => %w(1 2) }.each do |range, ids|
        it "returns #{ids.inspect} for range #{range.inspect}" do
          new_criteria.with(:user_id_i => range).map { |doc| doc["id"] }.sort.should == ids
        end
      end
    end
    
    describe "not searches" do
      it "finds the correct documents for not nil" do
        server.index_docs([
            :id => "3", :enabled_b => true, :text_t => "Marek Mintal", :popularity_i => 1, 
            :type => "Offer"
          ]
        )
        server.commit
        raise "There should be 3 docs" if new_criteria.total_entries != 3
        new_criteria.with(:user_id_i.not => nil).map { |h| h["id"] }.should == %w(1 2)
      end
      
      it "finds the correct values for not specific value" do
        new_criteria.with(:user_id_i.not => 1).map { |h| h["id"] }.should ==%w(2)
      end
    end
    
    describe "gt and lt searches" do
      { :gt => %w(2), :gte => %w(1 2), :lt => [], :lte => %w(1) }.each do |type, ids|
        it "finds ids #{ids.inspect} for #{type}" do
          new_criteria.with(:user_id_i.send(type) => 1).map { |row| row["id"] }.sort.should == ids
        end
      end
    end
    
    it "combines filters" do
      new_criteria.with(:user_id_i => 1, :enabled_b => false).total_entries.should == 1
      new_criteria.with(:user_id_i => 1, :enabled_b => true).total_entries.should == 0
    end
    
    it "uses without correctly" do
      new_criteria.without(:user_id_i => 1).map { |row| row.fetch("id") }.should == %w(2)
      new_criteria.without(:user_id_i => 2).map { |row| row.fetch("id") }.should == %w(1)
      new_criteria.without(:user_id_i => 2).without(:user_id_i => 1).map { |row| row.fetch("id") }.should == []
    end
    
    it "uses the correct orders" do
      new_criteria.order("id desc").map { |row| row.fetch("id") }.should == %w(2 1)
      new_criteria.order("id asc").map { |row| row.fetch("id") }.should == %w(1 2)
    end
    
    it "uses the correct pagination attributes" do
      new_criteria.with(:user_id_i => 1, :enabled_b => false).total_entries.should == 1
      new_criteria.with(:user_id_i => 1, :enabled_b => false).length.should == 1
      new_criteria.with(:user_id_i => 1, :enabled_b => false).paginate(:page => 10).total_entries.should == 1
      new_criteria.with(:user_id_i => 1, :enabled_b => false).paginate(:page => 10).length.should == 0
      
      new_criteria.paginate(:per_page => 1, :page => 1).map { |row| row.fetch("id") }.should == %w(1)
      new_criteria.paginate(:per_page => 1, :page => 2).map { |row| row.fetch("id")  }.should == %w(2)
    end
    
    it "handels empty results correctly" do
      results = new_criteria.with(:user_id_i => 1, :enabled_b => true)
      results.total_entries.should == 0
      results.current_page.should == 1
    end
    
    it "only sets specific attributes" do
      results = new_criteria.select(:user_id_i).with(:user_id_i => 1)
      results.length.should == 1
      results.first.should == { "id" => "1", "user_id_i" => 1 }
    end
  end
  
  describe "#facets" do
    it "returns the correct facets hash" do
      server.index_docs([:id => "3", :type => "Offer", :user_id_i => 3, :enabled_b => false, 
          :text_t => "Hans Müller", :popularity_i => 10, :type => "Offer"
        ]
      )
      server.commit
      new_criteria.facet_fields(:text_t).execute.facets.should == {"text_t"=>{"mintal"=>1, "marek"=>1, "meyer"=>1, "müller"=>1, "han"=>2}}
    end
  end
  
  describe "#execute_async" do
    it "is working" do
      server.index_docs([
        { :id => "1", :type => "Offer", :popularity_i => 1 },
        { :id => "2", :type => "Offer", :popularity_i => 10 },
        { :id => "3", :type => "Offer", :popularity_i => 100 },
      ])
      server.commit
      new_criteria.select("id").execute_async do |collection|
        @collection = collection
      end
      new_criteria.server.run

      @collection.should be_kind_of(Supernova::Collection)
      @collection.count.should == 3
      @collection.should == [{ "id" => "1" }, { "id" => "2" }, { "id" => "3" }]
    end
  end
  
  describe "#facet_queries" do
    it "returns the correct result" do
      server.index_docs(
        [
          { :id => "1", :type => "Offer", :popularity_i => 1 },
          { :id => "2", :type => "Offer", :popularity_i => 10 },
          { :id => "3", :type => "Offer", :popularity_i => 100 },
        ]
      )
      server.commit
      col = new_criteria.facet_queries(:one => "popularity_i:[* TO 1]", :ten => "popularity_i:[* TO 10]", :hundred => "popularity_i:[* TO 100]").execute
      col.facet_queries.should == { :one => 1, :ten => 2, :hundred => 3 }
    end
  end
  
  describe "#ids" do
    it "only returns the ids in a collection" do
      result = new_criteria.ids
      result.should be_kind_of(Supernova::Collection)
      result.should == [1, 2]
      result.total_entries.should == 2
    end
    
    it "does include facets" do
      new_criteria.facet_fields(:enabled_b).ids.facets.should == { "enabled_b" => { "true" => 1, "false" => 1 } }
    end
    
    it "returns 0 rows" do
      response = new_criteria.rows(0).facet_fields(:enabled_b).ids
      response.should be_empty
      response.facets.should == { "enabled_b" => { "true" => 1, "false" => 1 } }
    end
  end
  
  describe "with mapping" do
    before(:each) do
      name = "Class#{Time.now.to_f.to_s.gsub(".", "")}"
      eval("class #{name} < Supernova::SolrIndexer; end")
      @clazz = name.constantize
      @clazz.has :location, :type => :string
      @clazz.has :city, :type => :string
    end
    
    it "returns the correct facets" do
      row1 = { "id" => 1, "location" => "Hamburg", "type" => "Offer" }
      row2 = { "id" => 2, "location" => "Hamburg", "type" => "Offer" }
      row3 = { "id" => 3, "location" => "Berlin", "type" => "Offer" }
      @clazz.new.index_rows([row1, row2, row3])
      @clazz.facet_fields(:location).execute.facets.should == { :location=>{ "Berlin"=>1, "Hamburg"=>2 } }
    end
    
    describe "#nin and in" do
      before(:each) do
        row1 = { "id" => 1, "location_s" => "Hamburg", "type" => "Offer" }
        row2 = { "id" => 2, "location_s" => "Hamburg", "type" => "Offer" }
        row3 = { "id" => 3, "location_s" => "Berlin", "type" => "Offer" }
        row4 = { "id" => 4, "location_s" => "München", "type" => "Offer" }
        server.truncate
        server.index_docs([row1, row2, row3, row4])
        server.commit
      end
      
      it "correctly handels nin searches" do
        @clazz.with(:location_s.in => %w(Hamburg)).execute.map { |row| row.fetch("id") }.should == %w(1 2)
        @clazz.with(:location_s.in => %w(Hamburg Berlin)).execute.map { |row| row.fetch("id") }.should == %w(1 2 3)
      end
      
      it "correctly handels nin queries" do
        @clazz.with(:location_s.nin => %w(Hamburg)).execute.map { |row| row.fetch("id") }.should == ["3", "4"]
        @clazz.with(:location_s.nin => %w(Hamburg Berlin)).execute.map { |row| row.fetch("id") }.should == ["4"]
      end
    end
  end
end
