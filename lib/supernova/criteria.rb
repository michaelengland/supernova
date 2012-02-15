class Supernova::Criteria
  DEFAULT_PER_PAGE = 25
  FIRST_PAGE = 1
  
  attr_accessor :filters, :search_options, :clazz, :results

  class << self
    def method_missing(*args)
      scope = self.new
      if scope.respond_to?(args.first)
        scope.send(*args)
      else
        super
      end
    end
  
    def select(*args)
      self.new.send(:select, *args)
    end
    
    def immutable_by_default!
      @immutable_by_default = true
    end
    
    def mutable_by_default!
      @immutable_by_default = false
    end
    
    def immutable_by_default?
      @immutable_by_default == true
    end
  end

  def initialize(clazz = nil)
    self.clazz = clazz
    self.filters = {}
    self.search_options = {}
    self.immutable! if self.class.immutable_by_default?
  end
  
  def immutable!
    @immutable = true
  end
  
  def immutable?
    @immutable == true
  end

  def for_classes(clazzes)
    merge_filters :classes, [clazzes].flatten
  end
  
  def attribute_mapping(mapping)
    merge_search_options :attribute_mapping, mapping
  end

  def order(*order_options)
    merge_search_options :order, order_options
  end

  def limit(limit_option)
    merge_search_options :limit, limit_option
  end

  def group_by(group_option)
    merge_search_options :group_by, group_option
  end

  def search(*terms)
    merge_filters_array :search, terms
  end

  def with(filters)
    merge_search_options :with, filters
  end
  
  def where(*args)
    with(*args)
  end
  
  def without(filters)
    self_or_clone.tap do |soc|
      soc.filters[:without] ||= Hash.new
      filters.each do |key, value|
        soc.filters[:without][key] ||= Array.new
        soc.filters[:without][key] << value if !soc.filters[:without][key].include?(value)
      end
    end
  end

  def select(*fields)
    merge_filters_array :select, fields
  end
  
  def facet_fields(*fields)
    merge_filters_array :facets, fields
  end
  
  def facet_queries(hash)
    merge_search_options :facet_queries, hash
  end

  def conditions(filters)
    merge_filters :conditions, filters
  end

  def paginate(pagination_options)
    merge_search_options :pagination, pagination_options
  end
  
  def rows(rows)
    merge_search_options :rows, rows
  end
  
  def start(start)
    merge_search_options :start, start
  end
  
  def near(*coordinates)
    merge_search_options :geo_center, normalize_coordinates(*coordinates)
  end
  
  def within(distance)
    merge_search_options :geo_distance, distance
  end
  
  def options(options_hash)
    merge_search_options :custom_options, options_hash
  end
  
  def normalize_coordinates(*args)
    flattened = args.flatten
    if (lat = read_first_attribute(flattened.first, :lat, :latitude)) && (lng = read_first_attribute(flattened.first, :lng, :lon, :longitude))
      { :lat => lat.to_f, :lng => lng.to_f }
    elsif flattened.length == 2
      { :lat => flattened.first.to_f, :lng => flattened.at(1).to_f }
    end
  end
  
  def read_first_attribute(object, *keys)
    keys.each do |key|
      return object.send(key) if object.respond_to?(key)
    end
    nil
  end

  def merge_filters(key, value)
    merge_filters_or_search_options(:filters, key, value)
  end
  
  def merge_filters_array(key, fields)
    self_or_clone.tap do |soc|
      soc.search_options[key] ||= Array.new
      fields.flatten.each do |field|
        soc.search_options[key] << field if !soc.search_options[key].include?(field)
      end
    end
  end
  
  def clone
    Marshal.load(Marshal.dump(self))
  end
  
  def self_or_clone
    immutable? ? clone : self
  end

  def merge_search_options(key, value)
    merge_filters_or_search_options(:search_options, key, value)
  end
  
  def except(key)
    self_or_clone.tap do |soc|
      soc.search_options.delete(key)
    end
  end
  
  def valid_with_filter?(value)
    !(value.respond_to?(:blank?) && value.blank?) && !(value.respond_to?(:empty?) && value.empty?)
  end

  def merge_filters_or_search_options(reference_method, key, value)
    self_or_clone.tap do |soc|
      reference = soc.send(reference_method)
      if key == :with
        reference[:with] ||= Array.new
        if valid_with_filter?(value)
          if value.is_a?(Array)
            reference[:with] += value
          else 
            reference[:with] << value
          end
        end
      elsif value.is_a?(Hash)
        reference[key] ||= Hash.new
        reference[key].merge!(value)
      elsif [:select, :order].include?(key)
        reference[key] ||= Array.new
        reference[key] += (value || [])
      else
        reference[key] = value
      end
    end
  end

  def to_parameters
    implement_in_subclass
  end
  
  def populate
    @results = execute if !populated?
    self
  end
  
  def to_a
    populate
    results
  end
  
  def populated?
    instance_variables.map(&:to_s).include?("@results")
  end
  
  def execute
    implement_in_subclass
  end
  
  def current_page
    pagination_attribute_when_greater_zero(:page) || 1
  end
  
  def per_page
    ret = self.search_options[:pagination][:per_page] if self.search_options[:pagination]
    ret = DEFAULT_PER_PAGE if ret.nil?
    ret
  end
  
  def pagination_attribute_when_greater_zero(attribute)
    if self.search_options[:pagination] && self.search_options[:pagination][attribute].to_i > 0
      self.search_options[:pagination][attribute] 
    end
  end

  def implement_in_subclass
    raise "implement in subclass"
  end
  
  def merge(other_criteria)
    ret = self_or_clone
    other_criteria.filters.each do |key, value|
      ret = ret.merge_filters(key, value)
    end
    other_criteria.search_options.each do |key, value|
      ret = ret.merge_search_options(key, value)
    end
    ret
  end

  def method_missing(*args, &block)
    if Supernova::Collection.instance_methods.map(&:to_s).include?(args.first.to_s)
      populate
      @results.send(*args, &block)
    elsif self.named_scope_defined?(args.first)
      self.merge(self.search_options[:named_scope_class].send(*args)) # merge named scope and current criteria
    else
      super
    end
  end
  
  def named_scope_class(clazz)
    merge_search_options :named_scope_class, clazz
  end
  
  def named_scope_defined?(name)
    self.search_options[:named_scope_class] && self.search_options[:named_scope_class].respond_to?(:defined_named_search_scopes) && self.search_options[:named_scope_class].defined_named_search_scopes.respond_to?(:include?) && self.search_options[:named_scope_class].defined_named_search_scopes.include?(name)
  end
end