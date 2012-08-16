require "json"
require "fileutils"
require "time"
require "typhoeus"

class Supernova::SolrIndexer
  attr_accessor :options, :db, :ids, :local_solr, :current_json_string
  attr_writer :debug
  
  include Supernova::Solr
  
  class << self
    def field_definitions
      @field_definitions ||= {}
    end
    
    def select_fields
      field_definitions.map do |key, attributes|
        attributes[:virtual] != true ? key : nil
      end.compact
    end
    
    def has(key, attributes)
      field_definitions[key] = attributes.is_a?(Hash) ? attributes : { :type => attributes }
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
      Supernova::SolrCriteria.new(self.clazz).attribute_mapping(self.field_definitions).named_scope_class(self)
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
    :location => :p,
    :double => :d,
    :string_array => :ms
  }
  
  def initialize(options = {})
    options.each do |key, value|
      self.send(:"#{key}=", value) if self.respond_to?(:"#{key}=")
    end
    self.options = options
    self.ids ||= :all
  end
  
  def ids=(new_ids)
    @ids = new_ids
    @cached = {}
  end
  
  def cached
    @cached ||= {}
  end
  
  def debug(message)
    response = true
    time = Benchmark.realtime do
      response = yield if block_given?
    end
    if @debug == true
      message.gsub!("%COUNT%", response.count.to_s) if message.include?("%COUNT%") && response.respond_to?(:count)
      message.gsub!("%TIME%", "%.3f" % time)   if message.include?("%TIME%")
      puts "%s: %s" % [Time.now.iso8601(3), message]
    end
    response
  end
  
  def index!
    index_query(query_to_index)
  end
  
  def map_for_solr(row)
    map_hash_keys_to_solr(
      self.before_index(row)
    )
  end
  
  def before_index(row)
    row
  end
  
  def map_hash_keys_to_solr(hash)
    @indexed_at ||= Time.now.utc.iso8601.to_s
    if hash["id"] && self.table_name
      hash["record_id_i"] = hash["id"]
      hash["id"] = [self.table_name, hash["id"]].compact.join("/") 
    end
    hash["indexed_at_dt"] = @indexed_at
    self.class.field_definitions.each do |field, options|
      if hash.has_key?(field.to_s)
        value = hash.delete(field.to_s)
        if options[:type] == :date
          if value.is_a?(Date)
            value = "#{value}T00:00:00Z" 
          elsif value.respond_to?(:utc)
            value = value.utc.iso8601
          end
        end
        hash["#{field}_#{self.class.suffix_from_type(options[:type])}"] = value
      end
    end
    hash["type"] = self.class.clazz.to_s if self.class.clazz
    hash
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
    fields << %("#{self.class.clazz}" AS type) if self.class.clazz
    fields
  end
  
  def defined_fields
    self.class.field_definitions.map do |field, options|
      field.to_s if options[:virtual] != true
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
    if db.respond_to?(:query)
      db.query(query, :as => :hash)
    else
      db.select_all(query)
    end
  end
  
  def rows(query = nil)
    debug "fetched rows in %TIME%" do
      query_db(query || query_to_index)
    end
  end
  
  def index_rows(rows)
    debug "mapped %COUNT% rows to solr in %TIME%" do
      rows.map! { |r| map_for_solr(r) }
    end
    debug "indexed #{rows.length} rows with json in %TIME%" do
      index_with_json(rows)
    end
  end
  
  def index_with_json(rows)
    return false if rows.empty?
    index_with_json_string(rows)
  end
  
  def solr_rows_to_index_for_query(query)
    query_db(query).map do |row|
      map_for_solr(row)
    end
  end
  
  def index_query(query)
    debug "getting rows for #{query[0,100]}"
    index_rows(query_db(query))
  end

  def index_with_json_string(rows)
    rows.each do |row|
      append_to_json_string(row)
    end
    finalize_json_string
    post_json_string
  end
  
  def append_to_json_string(row)
    if self.current_json_string.nil?
      self.current_json_string = "\{\n"
    else
      self.current_json_string << ",\n"
    end
    self.current_json_string << %("add":#{{:doc => row.delete_if { |key, value| value.nil? }}.to_json})
  end
  
  def finalize_json_string
    self.current_json_string << "\n}"
  end
  
  def post_json_string
    Typhoeus::Request.post("#{solr_update_url}?commit=true", 
      :body => self.current_json_string, 
      :headers => { "Content-type" => "application/json; charset=utf-8" }
    ).tap do |response|
      self.current_json_string = nil
    end
  end
  
  def ids_given?
    self.ids.is_a?(Array)
  end
  
  def solr_url
    Supernova::Solr.url.present? ? Supernova::Solr.url.to_s.gsub(/\/$/, "") : nil
  end
  
  def solr_update_url
    "#{solr_url}/update/json"
  end
end
