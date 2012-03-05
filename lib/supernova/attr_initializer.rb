module Supernova::AttrInitializer
  module InstanceMethods
    def initialize(attributes = {})
      attributes.each do |key, value|
        self.send(:"#{key}=", value)
      end
    end
  end
  
  module ClassMethods
    def attr_initializer(*args)
      args.each do |arg|
        attr_accessor arg
      end
    end
  end
  
  def self.included(base)
    base.send(:include, Supernova::AttrInitializer::InstanceMethods)
    base.extend(Supernova::AttrInitializer::ClassMethods)
  end
end
