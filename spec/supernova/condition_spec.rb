require 'spec_helper'

describe "Supernova::Condition" do
  it "can be initialize" do
    cond = Supernova::Condition.new(:user_id, :not)
    cond.key.should == :user_id
    cond.type.should == :not
  end
  
  describe "equality" do
    it "returns true when the same" do
      :user_id.not.should == :user_id.not
    end
    
    it "returns false when other key" do
      :user_id.not.should_not == :other_user_id.not
    end
    
    it "returns false when other method" do
      :user_id.in.should_not == :user_id.not
    end
    
    it "returns true when the same" do
      :user_id.not.should be_eql(:user_id.not)
    end
    
    it "returns false when other key" do
      :user_id.not.should_not be_eql(:other_user_id.not)
    end
    
    it "returns false when other method" do
      :user_id.in.should_not be_eql(:user_id.not)
    end
    
    it "works for hashes" do
      a = { :user_id.in => 1 }
      a[:user_id.in] = 2
      a.keys.length.should == 1
      a[:user_id.in].should == 2
      a[:user_id.not] = 2
      a.keys.length.should == 2
    end
  end
  
  describe "#or_key_and_value", :wip => true do
    it "returns the correct filter" do
      ne = double("ne", :lat => 48.0, :lng => 12.0)
      sw = double("sw", :lat => 47.0, :lng => 11.0)
      bounding_box = double("bbox", :ne => ne, :sw => sw)
      :pt.in.or_key_and_value(bounding_box).should == "pt:[47.0,11.0 TO 48.0,12.0]"
    end
    
    it "returns the correct filter" do
      ne = double("ne", :lat => 48.0, :lng => 12.0)
      sw = double("sw", :lat => 47.0, :lng => 11.0)
      bounding_box = double("bbox", :ne => ne, :sw => sw)
      :pt.inside.or_key_and_value(bounding_box).should == "pt:{47.0,11.0 TO 48.0,12.0}"
    end
    
    it "returns {!geofilt} when center" do
      center = Supernova::Coordinate.new(:lat => 47, :lng => 11)
      circle = Supernova::Circle.new(:center => center, :radius_in_meters => 10)
      :center.in.or_key_and_value(circle).should == "{!geofilt}"
    end
    
  end
  
  describe "solr_filter_for", :wip => true do
    it "returns the correct filter" do
      sw = Geokit::LatLng.new(47.1, 11.1)
      ne = Geokit::LatLng.new(48.2, 12.2)
      bounds = Geokit::Bounds.new(sw, ne)
      :location_p.inside.solr_filter_for(bounds).should == "location_p:{47.1,11.1 TO 48.2,12.2}"
    end
    
    
    it "returns the correct filter for numbers" do
      :user_id.not.solr_filter_for(7).should == "!user_id:7"
    end
    
    it "returns the correct filter for numbers" do
      :user_id.ne.solr_filter_for(7).should == "!user_id:7"
    end
    
    it "returns the correct filter for in" do
      :user_id.in.solr_filter_for([1, 2, 3]).should == "user_id:1 OR user_id:2 OR user_id:3"
    end
    
    it "returns the correct filter for in when ranges are used" do
      :user_id.in.solr_filter_for(Range.new(1, 3)).should == "user_id:[1 TO 3]"
    end
    
    it "returns the correct filter for in when nil is in array" do
      :user_id.in.solr_filter_for([1, 2, nil]).should == "user_id:1 OR user_id:2 OR !user_id:[* TO *]"
    end
    
    it "returns the correct filter for nin" do
      :user_id.nin.solr_filter_for([1, 2, 3]).should == "!(user_id:1 OR user_id:2 OR user_id:3)"
    end
    
    it "returns the correct filter for nin when ranges are used" do
      :user_id.nin.solr_filter_for(Range.new(1, 3)).should == "user_id:{* TO 1} OR user_id:{3 TO *}"
    end
    
    it "returns the correct filter for nin when nil is in array" do
      :user_id.nin.solr_filter_for([1, 2, nil]).should == "!(user_id:1 OR user_id:2 OR !user_id:[* TO *])"
    end
    
    it "returns the correct filter for not nil" do
      :user_id.not.solr_filter_for(nil).should == "user_id:[* TO *]"
    end
    
    it "returns the correct filter for gt" do
      :user_id.gt.solr_filter_for(1).should == "user_id:{1 TO *}"
    end
    
    it "returns the correct filter for gte" do
      :user_id.gte.solr_filter_for(1).should == "user_id:[1 TO *]"
    end
    
    it "returns the correct filter for lt" do
      :user_id.lt.solr_filter_for(1).should == "user_id:{* TO 1}"
    end
    
    it "returns the correct filter for lt" do
      :user_id.lte.solr_filter_for(1).should == "user_id:[* TO 1]"
    end
  end
  
  
end
