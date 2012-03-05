require "supernova/attr_initializer"

describe "Supernova::AttrInitializer" do
  it "implements attr_initializer" do
    class User
      include Supernova::AttrInitializer
      attr_initializer :name, :age
    end
    
    usr = User.new(:name => "Hans", :age => 10)
    usr.name.should == "Hans"
    usr.age.should == 10
  end
end