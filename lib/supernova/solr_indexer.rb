require "json"

class Supernova::SolrIndexer
  attr_accessor :options, :db, :ids
  attr_writer :index_file_path
  
  include Supernova::Solr
  
  class << self
    def field_definitions
      @field_definitions ||= {}
    end
    
    def has(key, attributes)
      field_definitions[key] = attributes
    end
    
    def clazz(class_name =:only_return)
      @clazz = class_name if class_name != :only_return
      @clazz
    end
    
    def table_name(name = :only_return)
      @table_name = name if name != :only_return
      @table_name
    end
    
    def method_missing(*args)
      if search_scope.respond_to?(args.first)
        search_scope.send(*args)
      else
        super
      end
    end
    
    def search_scope
      Supernova::SolrCriteria.new(self.clazz).attribute_mapping(self.field_definitions)
    end
  end
  
  FIELD_SUFFIX_MAPPING = {
    :raw => nil,
    :string => :s,
    :text => :t,
    :int => :i,
    :integer => :i,
    :sint => :si,
    :float => :f,
    :date => :dt,
    :boolean => :b,
    :location => :p
  }
  
  def initialize(options = {})
    options.each do |key, value|
      self.send(:"#{key}=", value) if self.respond_to?(:"#{key}=")
    end
    self.options = options
    self.ids ||= :all
  end
  
  def index!
    index_query(query_to_index) do |row|
      row_to_solr(row)
    end
  end
  
  def row_to_solr(row)
    row
  end
  
  def table_name
    self.class.table_name || (self.class.clazz && self.class.clazz.respond_to?(:table_name) ? self.class.clazz.table_name : nil)
  end
  
  def query_to_index
    raise "no table_name defined" if self.table_name.nil?
    query = "SELECT #{select_fields.join(", ")} FROM #{self.table_name}"
    query << " WHERE id IN (#{ids.join(", ")})" if ids_given?
    query
  end
  
  def default_fields
    fields = ["id"]
    fields << %("#{self.class.clazz}" AS type_s) if self.class.clazz
    fields
  end
  
  def defined_fields
    self.class.field_definitions.map do |field, options|
      sql_column_from_field_and_type(field, options[:type]) if options[:virtual] != true
    end.compact
  end
  
  def select_fields
    default_fields + defined_fields
  end
  
  def validate_lat(lat)
    float_or_nil_when_abs_bigger_than(lat, 90)
  end
  
  def validate_lng(lng)
    float_or_nil_when_abs_bigger_than(lng, 180)
  end
  
  def float_or_nil_when_abs_bigger_than(value, border)
    return nil if value.to_s.strip.length == 0
    value_f = value.to_f
    value_f.abs > border ? nil : value_f
  end
  
  def sql_column_from_field_and_type(field, type)
    return sql_date_column_from_field(field) if type == :date
    if suffix = self.class.suffix_from_type(type)
      "#{field} AS #{field}_#{suffix}"
    else
      raise "no suffix for #{type} defined"
    end
  end
  
  def self.suffix_from_type(type)
    FIELD_SUFFIX_MAPPING[type.to_sym]
  end
  
  def self.solr_field_for_field_name_and_mapping(field, mapping)
    [field, mapping && mapping[field.to_sym] ? suffix_from_type(mapping[field.to_sym][:type]) : nil].compact.join("_")
  end
  
  def sql_date_column_from_field(field)
    %(IF(#{field} IS NULL, NULL, CONCAT(REPLACE(#{field}, " ", "T"), "Z")) AS #{field}_dt)
  end
  
  def query_db(query)
    db.send(db.respond_to?(:query) ? :query : :select_all, query)
  end
  
  def index_query(query)
    query_db(query).each do |row|
      yield(row) if block_given?
      write_to_file(row)
    end
    finish
  end
  
  def ids_given?
    self.ids.is_a?(Array)
  end
  
  def index_file_path
    @index_file_path ||= File.expand_path("/tmp/index_file_#{Time.now.to_i}.json")
  end
  
  def write_to_file(to_index)
    prefix = ",\n"
    if !stream_open?
      index_file_stream.puts "{"
      prefix = nil
    end
    filtered = to_index.inject({}) do |hash, (key, value)|
      hash[key] = value if value.to_s.strip.length > 0
      hash
    end
    index_file_stream.print(%(#{prefix}"add":#{({:doc => filtered}).to_json}))
  end
  
  def finish
    raise "nothing to index" if !stream_open?
    index_file_stream.puts("\}")
    index_file_stream.close
    do_index_file
  end
  
  def stream_open?
    !@index_file_stream.nil?
  end
  
  def index_file_stream
    @index_file_stream ||= File.open(index_file_path, "w")
  end
  
  def solr_url
    Supernova::Solr.url
  end
  
  def do_index_file(options = {})
    raise "solr not configured" if solr_url.nil?
    cmd = if options[:local]
      %(curl -s '#{solr_url}/update/json?commit=true\\&stream.file=#{index_file_path}')
    else
      %(cd #{File.dirname(index_file_path)} && curl -s '#{solr_url}/update/json?commit=true' --data-binary @#{File.basename(index_file_path)} -H 'Content-type:application/json')
    end
    system(cmd)
  end
end