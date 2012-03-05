require "supernova/coordinate"

class Supernova::Circle
  include Supernova::AttrInitializer
  attr_initializer :center, :radius_in_meters
end