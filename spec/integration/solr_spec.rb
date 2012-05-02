# -*- encoding : utf-8 -*-
require "spec_helper_ar"
require "webmock/rspec"

describe "Solr" do
  before(:each) do
    WebMock.disable!
    Supernova::Solr.instance_variable_set("@connection", nil)
    Supernova::Solr.url = "http://localhost:8983/solr/supernova_test"
    Supernova::Solr.truncate!
    Offer.criteria_class = Supernova::SolrCriteria
    root = Geokit::LatLng.new(47, 11)
    # endpoint = root.endpoint(90, 50, :units => :kms)
    e_lat = 46.9981112912042
    e_lng = 11.6587158814378
    Supernova::Solr.add(:id => "offers/1", :type => "Offer", :user_id_i => 1, :enabled_b => false, 
      :text_t => "Hans Meyer", :popularity_i => 10, 
      :location_p => "#{root.lat},#{root.lng}", :type => "Offer"
    )
    Supernova::Solr.add(:id => "offers/2", :user_id_i => 2, :enabled_b => true, :text_t => "Marek Mintal", 
      :popularity_i => 1, 
      :location_p => "#{e_lat},#{e_lng}", :type => "Offer"
    )
    Supernova::Solr.commit!
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

  describe "logging" do
    before(:each) do
      Supernova.logger = logger
      Supernova::Solr.truncate!
      indexer = Supernova::SolrIndexer.new
      indexer.index_with_json_string([
          { :title_s => "Title1", :id => 1, :type => "Record" }, 
          { :title_s => "Title2", :id => 2, :type => "Record" } 
        ]
      )
    end

    it "should log all queries when logger set" do
      Supernova::SolrCriteria.where(:id => 1).only_ids.typhoeus_response
      logs = logger.logs
      logs.count.should == 1
      logs.first.first.should match(/SUPERNOVA SOLR REQUEST.*finished in/)
    end

    it "also logs when using execute_async" do
      crit = Supernova::SolrCriteria.where(:id => 1).only_ids
      response = nil
      crit.execute_async do |result|
        response = result
      end
      new_criteria.hydra.run
      response.should == [{"id"=>"1"}]
      logs = logger.logs
      logs.count.should == 1
      logs.first.first.should match(/SUPERNOVA SOLR REQUEST.*finished in/)
    end
  end
  
  describe "#index_with_json_string" do
    it "indexes the correct rows" do
      Supernova::Solr.truncate!
      indexer = Supernova::SolrIndexer.new
      indexer.index_with_json_string([
          { :title_s => "Title1", :id => 1, :type => "Record" }, 
          { :title_s => "Title2", :id => 2, :type => "Record" } 
        ]
      )
      response = JSON.parse(Typhoeus::Request.post(Supernova::Solr.select_url, :params => { :q=>'*:*', :start=>0, :rows=>10, :sort => "id asc", :wt => "json" }).body)
      response["response"]["docs"].first.should == { "title_s" => "Title1", "id" => "1", "type" => "Record" }
      response["response"]["docs"].at(1).should == { "title_s" => "Title2", "id" => "2", "type" => "Record" }
    end
  end
  
  describe "#indexing" do
    before(:each) do
      Supernova::Solr.truncate!
      Supernova::Solr.commit!
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
      OfferIndex.search_scope.first.instance_variable_get("@original_search_doc")["indexed_at_dt"].should_not be_nil
      OfferIndex.search_scope.total_entries.should == 2
      OfferIndex.search_scope.order("user_id desc").populate.results.should == [offer2, offer1]
      indexer.instance_variable_get("@index_file_path").should be_nil
    end
    
    it "indexes with a file" do
      offer1 = Offer.create!(:user_id => 1, :popularity => 10)
      offer2 = Offer.create!(:user_id => 2, :popularity => 20)
      indexer = OfferIndex.new(:db => ActiveRecord::Base.connection, :max_rows_to_direct_index => 0)
      indexer.options[:use_json_file] = true
      indexer.index!
      OfferIndex.search_scope.total_entries.should == 2
      OfferIndex.search_scope.first.instance_variable_get("@original_search_doc")["indexed_at_dt"].should_not be_nil
      OfferIndex.search_scope.order("user_id desc").populate.results.should == [offer2, offer1]
    end
    
    it "indexes with a local file" do
      offer1 = Offer.create!(:user_id => 1, :popularity => 10)
      offer2 = Offer.create!(:user_id => 2, :popularity => 20)
      indexer = OfferIndex.new(:db => ActiveRecord::Base.connection, :max_rows_to_direct_index => 0, :local_solr => true)
      indexer.options[:use_json_file] = true
      indexer.index!
      OfferIndex.search_scope.first.instance_variable_get("@original_search_doc")["indexed_at_dt"].should_not be_nil
      OfferIndex.search_scope.total_entries.should == 2
      OfferIndex.search_scope.order("user_id desc").populate.results.should == [offer2, offer1]
    end
    
    describe "with extra_attributes_from_doc method defined" do
      class OfferIndexWitheExtraSearchMethodFromDoc < Supernova::SolrIndexer
        has :user_id, :type => :integer
        has :popularity, :type => :integer
        has :upcased_text, :type => :text, :virtual => true
        has :text, :type => :text
        
        clazz Offer
        
        def extra_attributes_from_record(record)
          { :upcased_text => record.text.to_s.upcase.presence }
        end
      end
      
      it "sets the capitalize_text attribute" do
        Offer.create!(:user_id => 2, :popularity => 20, :text => "lower_text")
        indexer = OfferIndexWitheExtraSearchMethodFromDoc.new(:db => ActiveRecord::Base.connection)
        indexer.index!
        offer = OfferIndexWitheExtraSearchMethodFromDoc.search_scope.first
        offer.instance_variable_get("@original_search_doc")["upcased_text_t"].should == "LOWER_TEXT"
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
        new_criteria.search("text_t:Hans").map { |h| h["id"] }.should == [1]
        new_criteria.search("text_t:Hans").search("text_t:Meyer").map { |h| h["id"] }.should == [1]
        new_criteria.search("text_t:Marek").map { |h| h["id"] }.should == [2]
      end
      
      it "returns the correct options for a combined search" do
        new_criteria.search("text_t:Hans", "text_t:Marek").populate.results.should == []
      end
    end
    
    {
      "id" => "offers/1", "type" => "Offer", "user_id_i" => 1, "enabled_b" => false, "text_t" => "Hans Meyer", 
      "popularity_i" => 10, "location_p" => "47,11"
    }.each do |key, value|
      it "sets #{key} to #{value}" do
        doc = new_criteria.search("text_t:Hans").first.instance_variable_get("@original_search_doc")[key].should == value
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
        Supernova::Solr.truncate!
        Supernova::Solr.add(:id => "1", :location_p => inside.to_s, :type => "Test")
        Supernova::Solr.add(:id => "2", :location_p => outside.to_s, :type => "Test")
        Supernova::Solr.commit!
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
      { Range.new(2, 3) => [2], Range.new(3, 10) => [], Range.new(1, 2) => [1, 2] }.each do |range, ids|
        it "returns #{ids.inspect} for range #{range.inspect}" do
          new_criteria.with(:user_id_i => range).map { |doc| doc["id"] }.sort.should == ids
        end
      end
    end
    
    describe "not searches" do
      it "finds the correct documents for not nil" do
        Supernova::Solr.add(:id => "offers/3", :enabled_b => true, :text_t => "Marek Mintal", :popularity_i => 1, 
          :type => "Offer"
        )
        Supernova::Solr.commit!
        raise "There should be 3 docs" if new_criteria.total_entries != 3
        new_criteria.with(:user_id_i.not => nil).map { |h| h["id"] }.should == [1, 2]
      end
      
      it "finds the correct values for not specific value" do
        new_criteria.with(:user_id_i.not => 1).map { |h| h["id"] }.should == [2]
      end
    end
    
    describe "gt and lt searches" do
      { :gt => [2], :gte => [1, 2], :lt => [], :lte => [1] }.each do |type, ids|
        it "finds ids #{ids.inspect} for #{type}" do
          new_criteria.with(:user_id_i.send(type) => 1).map { |row| row["id"] }.sort.should == ids
        end
      end
    end
    
    it "returns the correct objects" do
      new_criteria.with(:user_id_i => 1).first.should be_an_instance_of(Offer)
    end
    
    { :id => 1, :user_id => 1, :enabled => false, :text => "Hans Meyer", :popularity => 10 }.each do |key, value|
      it "sets #{key} to #{value}" do
        doc = new_criteria.attribute_mapping(
          :user_id => { :type => :integer },
          :enabled => { :type => :boolean },
          :popularity => { :type => :integer },
          :text => { :type => :text}
        ).with(:id => "offers/1").first
        doc.send(key).should == value
      end
    end
    
    it "combines filters" do
      new_criteria.with(:user_id_i => 1, :enabled_b => false).total_entries.should == 1
      new_criteria.with(:user_id_i => 1, :enabled_b => true).total_entries.should == 0
    end
    
    it "uses without correctly" do
      new_criteria.without(:user_id_i => 1).map(&:id).should == [2]
      new_criteria.without(:user_id_i => 2).map(&:id).should == [1]
      new_criteria.without(:user_id_i => 2).without(:user_id_i => 1).map(&:id).should == []
    end
    
    it "uses the correct orders" do
      new_criteria.order("id desc").map(&:id).should == [2, 1]
      new_criteria.order("id asc").map(&:id).should == [1, 2]
    end
    
    it "uses the correct pagination attributes" do
      new_criteria.with(:user_id_i => 1, :enabled_b => false).total_entries.should == 1
      new_criteria.with(:user_id_i => 1, :enabled_b => false).length.should == 1
      new_criteria.with(:user_id_i => 1, :enabled_b => false).paginate(:page => 10).total_entries.should == 1
      new_criteria.with(:user_id_i => 1, :enabled_b => false).paginate(:page => 10).length.should == 0
      
      new_criteria.paginate(:per_page => 1, :page => 1).map(&:id).should == [1]
      new_criteria.paginate(:per_page => 1, :page => 2).map(&:id).should == [2]
    end
    
    it "handels empty results correctly" do
      results = new_criteria.with(:user_id_i => 1, :enabled_b => true)
      results.total_entries.should == 0
      results.current_page.should == 1
    end
    
    it "only sets specific attributes" do
      results = new_criteria.select(:user_id_i).with(:user_id_i => 1)
      results.length.should == 1
      results.first.should == { "id" => "offers/1", "user_id_i" => 1 }
    end
  end
  
  describe "#facets" do
    it "returns the correct facets hash" do
      Supernova::Solr.add(:id => "offers/3", :type => "Offer", :user_id_i => 3, :enabled_b => false, 
        :text_t => "Hans Müller", :popularity_i => 10, :type => "Offer"
      )
      Supernova::Solr.commit!
      new_criteria.facet_fields(:text_t).execute.facets.should == {"text_t"=>{"mintal"=>1, "marek"=>1, "meyer"=>1, "müller"=>1, "han"=>2}}
    end
  end
  
  describe "#execute_async" do
    it "is working" do
      Supernova::Solr.add(:id => "offers/1", :type => "Offer", :popularity_i => 1)
      Supernova::Solr.add(:id => "offers/2", :type => "Offer", :popularity_i => 10)
      Supernova::Solr.add(:id => "offers/3", :type => "Offer", :popularity_i => 100)
      Supernova::Solr.commit!
      
      new_criteria.select("id").execute_async do |collection|
        @collection = collection
      end
      new_criteria.hydra.run

      @collection.should be_kind_of(Supernova::Collection)
      @collection.count.should == 3
      @collection.should == [{ "id" => "offers/1" }, { "id" => "offers/2" }, { "id" => "offers/3" }]
    end
  end
  
  describe "#facet_queries" do
    it "returns the correct result" do
      Supernova::Solr.add(:id => "offers/1", :type => "Offer", :popularity_i => 1)
      Supernova::Solr.add(:id => "offers/2", :type => "Offer", :popularity_i => 10)
      Supernova::Solr.add(:id => "offers/3", :type => "Offer", :popularity_i => 100)
      Supernova::Solr.commit!
      col = new_criteria.facet_queries(:one => "popularity_i:[* TO 1]", :ten => "popularity_i:[* TO 10]", :hundred => "popularity_i:[* TO 100]").execute
      col.facet_queries.should == { :one => 1, :ten => 2, :hundred => 3 }
    end
  end
  
  describe "#typhoeus_response" do
    let(:response) { JSON.parse(new_criteria.typhoeus_response.body) }
    
    it "returns a hash" do
      response.should be_kind_of(Hash)
    end
    
    it "should not be empty" do
      response.keys.should_not be_empty
    end
    
    it "includes th ecorrect headers" do
      response.keys.sort.should == %w(responseHeader response).sort
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
        row1 = { "id" => 1, "location" => "Hamburg", "type" => "Offer" }
        row2 = { "id" => 2, "location" => "Hamburg", "type" => "Offer" }
        row3 = { "id" => 3, "location" => "Berlin", "type" => "Offer" }
        row4 = { "id" => 4, "location" => "München", "type" => "Offer" }
        Supernova::Solr.truncate!
        Supernova::Solr.commit!
        @clazz.new.index_rows([row1, row2, row3, row4])
      end
      
      it "correctly handels nin searches" do
        @clazz.with(:location.in => %w(Hamburg)).execute.map(&:id).should == [1, 2]
        @clazz.with(:location.in => %w(Hamburg Berlin)).execute.map(&:id).should == [1, 2, 3]
      end
      
      it "correctly handels nin queries" do
        @clazz.with(:location.nin => %w(Hamburg)).execute.map(&:id).should == [3, 4]
        @clazz.with(:location.nin => %w(Hamburg Berlin)).execute.map(&:id).should == [4]
      end
    end
  end
end