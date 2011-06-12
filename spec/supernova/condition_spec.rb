require 'spec_helper'

describe "Supernova::Condition" do
  it "can be initialize" do
    cond = Supernova::Condition.new(:user_id, :not)
    cond.key.should == :user_id
    cond.type.should == :not
  end
  
  describe "solr_filter_for" do
    it "returns the correct filter for numbers" do
      :user_id.not.solr_filter_for(7).should == "!user_id:7"
    end
    
    it "returns the correct filter for numbers" do
      :user_id.ne.solr_filter_for(7).should == "!user_id:7"
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