module SearchScope
  module ClassMethods
    attr_accessor :criteria_class, :defined_named_search_scopes
    
    def search_scope
      self.criteria_class.new(self)
    end
    
    def named_search_scope(name, &block)
      self.class.send(:define_method, name) do |*args|
        self.search_scope.instance_exec(*args, &block)
      end
      self.defined_named_search_scopes ||= []
      self.defined_named_search_scopes << name
    end
  end
end

require "search_scope/criteria"
require "search_scope/thinking_sphinx"