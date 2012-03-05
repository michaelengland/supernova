require "supernova/circle"

describe "Supernova::Circle" do
  let(:center) { Supernova::Coordinate.new(:lat => 47, :lng => 11) }
  
  it "can be initialized" do
    Supernova::Circle.new
  end
  
  it "can be initialized with center" do
    Supernova::Circle.new(:center => center).center.should == center
  end
  
  it "allows setting of radius_in_meters" do
    Supernova::Circle.new(:radius_in_meters => 101_00).radius_in_meters.should == 101_00
  end
end