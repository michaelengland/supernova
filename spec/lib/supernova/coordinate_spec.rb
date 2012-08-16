require "supernova/coordinate"

describe "Supernova::Coordinate" do
  it "can be initialized" do
    Supernova::Coordinate.new
  end
  
  it "allows setting of lat" do
    Supernova::Coordinate.new(:lat => 10).lat.should == 10
  end
  
  it "allows setting of lng" do
    Supernova::Coordinate.new(:lng => 10).lng.should == 10
  end
end