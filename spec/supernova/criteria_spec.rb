require File.expand_path("../spec_helper", File.dirname(__FILE__))
require "ostruct"

describe "Supernova::Criteria" do
  let(:scope) { Supernova::Criteria.new }
  before(:each) do
    scope.stub!(:execute).and_return [].paginate(:page => 1)
  end
  
  describe "#initialize" do
    it "can be initialized" do
      Supernova::Criteria.new.should be_an_instance_of(Supernova::Criteria)
    end
    
    it "sets the clazz_name" do
      Supernova::Criteria.new(Offer).clazz.should == Offer
    end
    
    it "allows setting immutable!" do
      a = Supernova::Criteria.new
      a.immutable!
      a.should be_immutable
    end
    
    it "automatically sets the criteria to immutable when globally enabled" do
      Supernova::Criteria.immutable_by_default!
      a = Supernova::Criteria.new
      a.should be_immutable
    end
  end
  
  [
    [:order, "popularity desc"],
    [:group_by, "title"],
    [:search, "query"],
    [:limit, 10],
    [:with, { :stars => 2 }],
    [:conditions, { :stars => 2 }],
    [:paginate, { :stars => 2 }],
    [:select, %w(stars)],
    [:near, "test"],
    [:within, 10],
    [:options, {}],
    [:without, {}],
    [:facet_fields, "name"]
  ].each do |args|
    it "returns the scope itself for #{args.first}" do
      scope.send(*args).should == scope
    end
    
    it "delegates all methods to the instance when responding to" do
      scope_double = Supernova::Criteria.new
      Supernova::Criteria.should_receive(:new).and_return scope_double
      scope_double.should_receive(args.first).with(*args[1..-1])
      Supernova::Criteria.send(*args)
    end
  end
  
  describe "#facet_fields" do
    it "sets the facets" do
      scope.facet_fields("title").facet_fields("name", "first_name").search_options[:facets].should == %w(title name first_name)
    end
  end
  
  describe "#order" do
    it "sets the order statement" do
      scope.order("popularity desc").search_options[:order].should == ["popularity desc"]
    end
  end
  
  describe "#group_by" do
    it "sets the group option" do
      scope.group_by("name").search_options[:group_by].should == "name"
    end
  end
  
  it "sets the limit option" do
    scope.limit(77).search_options[:limit].should == 77
  end
  
  describe "#search" do
    it "sets the query" do
      scope.search("title").search_options[:search].should == ["title"]
    end
  end
  
  describe "#for_classes" do
    it "sets the correct classes" do
      scope.for_classes([Offer, Host]).filters[:classes].should == [Offer, Host]
    end
    
    it "also sets single classes" do
      scope.for_classes(Offer).filters[:classes].should == [Offer]
    end
  end
  
  
  
  [:conditions].each do |method|
    describe "##{method}" do
      it "adds all filters to the #{method} block" do
        scope.send(method, { :length => 3, :height => 99 }).filters[:conditions].should == { :length => 3, :height => 99 }
      end
    end
  end
  
  it "sets select option" do
    scope.select(%w(a b)).search_options[:select].should == %w(a b)
  end
  
  it "sets the correct pagination fields" do
    scope.paginate(:page => 9, :per_page => 2).search_options[:pagination].should == { :page => 9, :per_page => 2 }
  end
  
  describe "#per_page" do
    it "allows setting of pagination to 0" do
      scope.paginate(:per_page => 0).per_page.should == 0
    end
    
    it "sets the per_page to the default when setting to nil" do
      scope.paginate(:per_page => nil).per_page.should == 25
    end
  end
  
  describe "#without" do
    it "sets the correct without filter" do
      scope.without(:user_id => 1).filters[:without].should == { :user_id => [1] }
    end
    
    it "combines multiple without filters" do
      scope.without(:user_id => 1).without(:user_id => 1).without(:user_id => 2).filters[:without].should == { :user_id => [1, 2] }
    end
  end
  
  describe "#with" do
    it "accepts string filters" do
      scope.with("a=1").search_options[:with].should == ["a=1"]
    end
    
    it "also accepts hashes" do
      scope.with(:a => 1).search_options[:with].should == [{ :a => 1 }]
    end
    
    it "merges various scopes" do
      scope.with(:a => 1).with("a=b").search_options[:with].should == [{ :a => 1 }, "a=b"]
    end
  end
  
  it "to_parameters raises an implement in subclass error" do
    lambda {
      scope.to_parameters
    }.should raise_error("implement in subclass")
  end
  
  it "to_a raises an implement in subclass error" do
    scope.unstub(:execute)
    lambda {
      scope.execute
    }.should raise_error("implement in subclass")
  end
  
  describe "#to_a" do
    it "calls populate" do
      scope.should_receive(:populate)
      scope.to_a
    end
    
    it "returns the results" do
      res = double("results")
      scope.stub!(:populate)
      scope.instance_variable_set("@results", res)
      scope.to_a.should == res
    end
  end
  
  describe "#populate" do
    it "returns self when" do
      scope.stub!(:populated?).and_return true
      scope.populate.should == scope
    end
    
    it "does not change @results when already populated" do
      res = double("results")
      scope.instance_variable_set("@results", res)
      scope.stub!(:populated?).and_return true
      scope.populate.should == scope
      scope.instance_variable_get("@results").should == res
    end
    
    it "returns the scope when not populated yet" do
      scope.populate.should == scope
    end
    
    it "calls execute" do
      scope.should_receive(:execute).and_return []
      scope.populate
    end
    
    it "assigns the result of populate" do
      result = double("result")
      scope.stub!(:execute).and_return result
      scope.populate
      scope.instance_variable_get("@results").should == result
    end
  end
  
  describe "#populated?" do
    it "returns false when @results not set" do
      scope.should_not be_populated
    end
    
    it "returns true when instance variable set" do
      scope.stub!(:execute).and_return []
      scope.populate
      scope.should be_populated
    end
  end
  
  describe "with to_a stubbed" do
    let(:array_double) { double("array") }
    
    before(:each) do
      scope.stub!(:to_a).and_return array_double
    end
    
    [ :first, :each, :count, :last, :total_entries ].each do |method|
      it "forwards #{method} to array" do
        results = double("ret")
        scope.instance_variable_set("@results", results)
        scope.should_receive(:populated?).and_return false
        scope.send(method)
      end
    end
    
    it "hands given blocks in" do
      array = [1, 2, 3]
      scope.instance_variable_set("@results", array)
      scope.stub!(:populated?).and_return true
      called = []
      scope.each do |i|
        called << i
      end
      called.should == array
    end
    
    it "does raise errors when array does not respond" do
      lambda {
        scope.rgne
      }.should raise_error(NoMethodError)
      
    end
  end
  
  describe "#clone" do
    it "returns a new Supernova::Criteria" do
      Supernova::Criteria.new.clone.should be_kind_of(Supernova::Criteria)
    end
    
    it "also clones the attributes" do
      a = Supernova::Criteria.new
      b = a.clone
      b.immutable?.should == false
      a.search_options[:a] = 1
      b.search_options[:a].should be_nil
    end
    
    it "makes the cloned collection immutable" do
      a = Supernova::Criteria.new
      a.immutable!
      b = a.clone
      b.immutable?.should == true
    end
  end
  
  describe "#self_or_clone" do
    it "returns self when immutable is off" do
      a = Supernova::Criteria.new
      a.self_or_clone.should == a
    end
    
    it "returns a clone when immutable is on" do
      a = Supernova::Criteria.new
      a.immutable!
      b = a.self_or_clone
      b.should be_kind_of(Supernova::Criteria)
      b.should_not == a
    end
  end
  
  describe "#merge_filters_array" do
    describe "when mutable" do
      it "returns self" do
        a = Supernova::Criteria.new
        a.merge_filters_array(:a, [1, 2, 3]).should == a
        a.search_options[:a].should == [1, 2, 3]
      end
    end
    
    describe "when immutable" do
      it "returns self" do
        a = Supernova::Criteria.new
        a.immutable!
        b = a.merge_filters_array(:a, [1, 2, 3])
        b.should_not == a
        a.search_options[:a].should be_nil
        b.search_options[:a].should == [1, 2, 3]
      end
    end
  end
  
  describe "#without" do
    describe "when mutable" do
      it "returns self" do
        a = Supernova::Criteria.new
        a.without(:a => 1).should == a
        a.filters[:without].should == { :a => [1] }
      end
    end
    
    describe "when immutable" do
      it "returns self" do
        a = Supernova::Criteria.new
        a.immutable!
        b = a.without(:a => 2)
        b.should_not == a
        a.filters[:without].should be_nil
        b.filters[:without].should == { :a => [2] }
      end
    end
  end
  
  
  describe "#merge_filters_or_search_options" do
    describe "when mutable" do
      it "returns self" do
        a = Supernova::Criteria.new
        a.merge_filters_or_search_options(:search_options, :per_page, 1).should == a
        a.search_options[:per_page].should == 1
      end
    end
    
    describe "when immutable" do
      it "returns a new criteria" do
        a = Supernova::Criteria.new
        a.immutable!
        b = a.merge_filters_or_search_options(:search_options, :per_page, 3)
        a.search_options[:per_page].should be_nil
        b.search_options[:per_page].should == 3
      end
    end
  end
  
  describe "#except" do
    describe "being mutable" do
      it "returns the criteria" do
        a = Supernova::Criteria.new
        a.except(:order).should be_kind_of(Supernova::Criteria)
      end
      
      it "removes the specified field" do
        a = Supernova::Criteria.new
        a.order("id").except(:order).search_options[:order].should be_nil
      end
    end
    
    describe "being immutable" do
      it "returns a different criteria with the field removed" do
        a = Supernova::Criteria.new.order("id").where(:a => 1)
        a.immutable!
        b = a.except(:order)
        b.search_options[:order].should be_nil
        b.search_options[:with].should == [{ :a => 1 }]
        a.search_options[:order].should == ["id"]
      end
    end
  end
  
  describe "#method_missing" do
    it "raises a no method error when methd not defined" do
      lambda {
        scope.method_missing(:rgne)
      }.should raise_error(NoMethodError)
    end
    
    it "forwards all array methods to @results" do
      results = double("results")
      scope.instance_variable_set("@results", results)
      results.should_receive(:index).with("1")
      scope.index("1")
    end
    
    it "calls named_scope_defined" do
      scope.should_receive(:named_scope_defined?).with(:rgne).and_return false
      scope.method_missing(:rgne) rescue nil
    end
    
    it "does not call named scopes when named_scope_defined? returns false" do
      clazz = double("clazz")
      scope = Supernova::Criteria.new(clazz)
      scope.stub(:named_scope_defined?).and_return false
      clazz.should_not_receive(:rgne)
    end
    
    it "it calls merge with self and returned scope" do
      clazz = double("clazz")
      scope = Supernova::Criteria.new.named_scope_class(clazz)
      scope.stub(:named_scope_defined?).and_return true
      rge_scope = double("rgne_scope")
      scope_ret = double("ret")
      clazz.should_receive(:rgne).with(1, 2).and_return scope_ret
      merge_ret = double("merge_ret")
      scope.should_receive(:merge).with(scope_ret).and_return merge_ret
      scope.method_missing(:rgne, 1, 2).should == merge_ret
    end
  end
  
  describe "#where" do
    it "delegates to with" do
      ret = double("ret")
      scope.should_receive(:with).with(:a => 9).and_return ret
      scope.where(:a => 9).should == ret
    end
  end
  
  describe "#attribute_mapping" do
    it "sets the attribute_mapping option" do
      mapping = { :title => { :type => :integer } }
      scope.attribute_mapping(mapping).search_options[:attribute_mapping].should == mapping
    end
  end
  
  it "allows setting the rows attributes" do
    scope.rows(11).search_options[:rows].should == 11
  end
  
  it "allows setting the start attributes" do
    scope.start(99).search_options[:start].should == 99
  end
  
  describe "#facet_queries" do
    it "adds the queries to the facet_queries array" do
      scope.facet_queries(:first => "1 = 1").facet_queries(:second => "2 = 2").search_options[:facet_queries].should == {
        :first => "1 = 1", :second => "2 = 2"
      }
    end
    
    it "allows merging of two scopes with facet queries" do
      scope.immutable!
      a = scope.facet_queries(:first => "1 = 1")
      b = scope.facet_queries(:second => "2 = 2")
      a.search_options[:facet_queries].should == { :first => "1 = 1" }
      b.search_options[:facet_queries].should == { :second => "2 = 2" }
      a.merge(b).search_options[:facet_queries].should == { :first => "1 = 1", :second => "2 = 2" }
    end
  end
  
  describe "#merge" do
    let(:criteria) { Supernova::Criteria.new.order("popularity asc").with(:a => 1).conditions(:b => 2).search("New Search") }
    let(:new_crit) { Supernova::Criteria.new.order("popularity desc").with(:c => 8).conditions(:e => 9).search("Search") }
    
    it "it returns the original criteria" do
      new_crit.merge(criteria).should == new_crit
    end
    
    it "merges e.g. the with filters" do
      new_crit.merge(criteria).search_options[:with].should == [{ :c => 8 }, { :a => 1 }]
    end
    
    it "merges e.g. the conditions filters" do
      new_crit.merge(criteria).filters[:conditions].should == { :b => 2, :e => 9 }
    end
    
    it "merges search search" do
      new_crit.merge(criteria).search_options[:search].should == ["New Search"]
    end
    
    it "correctly merges select statements" do
      Supernova::Criteria.new.select(:title).merge(Supernova::Criteria.new.select(:name)).search_options[:select].should == [:title, :name]
    end
    
    it "correctly merges the named_scope_class" do
      new_crit.named_scope_class(String)
      new_crit.merge(criteria).search_options[:named_scope_class].should == String
    end
    
    it "correctly merges the attribute_mapping" do
      mapping = { :title => { :type => :string } }
      new_crit.attribute_mapping(mapping)
      new_crit.merge(criteria).search_options[:attribute_mapping].should == mapping
    end
    
    it "uses the base attributes_mapping when " do
      mapping = { :title => { :type => :string }, :artist_name => { :type => :string } }
      other = Supernova::SolrCriteria.new.with(:artist_name => "name")
      Supernova::SolrCriteria.new.attribute_mapping(mapping).with(:title => "test").merge(other).to_params[:fq].should include("artist_name_s:name")
      Supernova::SolrCriteria.new.attribute_mapping(mapping).with(:title => "test").merge(other).to_params[:fq].should include("title_s:test")
    end
    
    it "calls merge on options" do
      criteria.stub!(:search_options).and_return({ :x => 2, :y => 9 })
      new_crit.stub!(:search_options).and_return({ :z => 3, :c => 1 })
      new_crit.should_receive(:merge_search_options).with(:x, 2).and_return(new_crit)
      new_crit.should_receive(:merge_search_options).with(:y, 9).and_return(new_crit)
      new_crit.merge(criteria)
    end
    
    it "calls merge filters on all filters" do
      criteria.stub!(:filters).and_return({ :a => 1, :c => 3 })
      new_crit.stub!(:filters).and_return({ :b => 2, :e => 1 })
      new_crit.should_receive(:merge_filters).with(:a, 1).and_return(new_crit)
      new_crit.should_receive(:merge_filters).with(:c, 3).and_return(new_crit)
      new_crit.merge(criteria)
    end
    
    describe "when immutable" do
      it "merges two filters but does not break " do
        a = Supernova::Criteria.new.with(:a => 1)
        a.immutable!
        b = Supernova::Criteria.new.with(:b => 2)
        b.immutable!
        c = a.merge(b)
        c.should_not == a
        c.should_not == b
        a.search_options[:with].should == [{ :a => 1 }]
        b.search_options[:with].should == [{ :b => 2 }]
        c.search_options[:with].should == [{ :a => 1 }, { :b => 2 }]
      end
    end
  end
  
  describe "#near" do
    it "sets the geo_center option" do
      scope.near([47, 11]).search_options[:geo_center].should == { :lat => 47.0, :lng => 11.0 }
    end
    
    it "can be called without an array" do
      scope.near(47, 11).search_options[:geo_center].should == { :lat => 47.0, :lng => 11.0 }
    end
  end
  
  describe "#within" do
    it "sets the distance to a value in meters when numeric given" do
      scope.within("test").search_options[:geo_distance].should == "test"
    end
  end
  
  describe "#options" do
    it "merges full hash into options" do
      scope.order("popularity desc").options(:test => "out", :order => "popularity asc").search_options[:custom_options].should == { :test => "out", :order => "popularity asc" }
    end
  end
  
  describe "normalize_coordinates" do
    it "returns a hash when array given" do
      scope.normalize_coordinates([47, 12]).should == { :lat => 47.0, :lng => 12.0 }
    end
    
    it "returns a hash when two parameters given" do
      scope.normalize_coordinates(47, 12).should == { :lat => 47.0, :lng => 12.0 }
    end
    
    [
      [:lat, :lng],
      [:lat, :lon],
      [:latitude, :longitude]
    ].each do |(lat_name, lng_name)|
      it "returns a hash when object responding to lat and lng is given" do
        scope.normalize_coordinates(OpenStruct.new(lat_name => 11, lng_name => 19)).should == { :lat => 11.0, :lng => 19.0 }
      end
    end
  end
  
  describe "#named_scope_defined?" do
    it "returns false when clazz is nil" do
      Supernova::Criteria.new.should_not be_named_scope_defined(:rgne)
    end
    
    it "returns false when clazz is present but not responding to defined_search_scopes" do
      Supernova::Criteria.new("test").should_not be_named_scope_defined(:rgne)
    end
    
    it "returns false when clazz is responding to defined_search_scopes but empty" do
      clazz = Class.new
      class << clazz
        attr_accessor :defined_named_search_scopes
      end
      clazz.defined_named_search_scopes = nil
      Supernova::Criteria.new.named_scope_class(clazz).should_not be_named_scope_defined(:rgne)
    end
    
    it "returns false when clazz is responding to defined_search_scopes but not included" do
      clazz = Class.new
      class << clazz
        attr_accessor :defined_named_search_scopes
      end
      clazz.defined_named_search_scopes = [:some_other]
      Supernova::Criteria.new.named_scope_class(clazz).should_not be_named_scope_defined(:rgne)
    end
    
    it "returns true when clazz is responding to defined_search_scopes and included" do
      clazz = Class.new
      class << clazz
        attr_accessor :defined_named_search_scopes
      end
      clazz.defined_named_search_scopes = [:rgne]
      Supernova::Criteria.new.named_scope_class(clazz).should be_named_scope_defined(:rgne)
    end
  end
  
  describe "#named_scope_class" do
    it "sets the named_scope_class search_option" do
      Supernova::Criteria.new.named_scope_class(String).search_options[:named_scope_class].should == String
    end
  end
end
