# -*- encoding : utf-8 -*-

class Supernova::SolrCriteria < Supernova::Criteria
  DEFAULT_Q = "*:*"

  attr_writer :solr_url

  def solr_url
    @solr_url || Supernova::Solr.url
  end

  def select_url
    "#{solr_url}/select"
  end

  def geo_circle_from_with
    geo_filter_in_with.at(1) if geo_filter_in_with
  end
  
  def geo_center_from_with
    geo_circle_from_with.center if geo_circle_from_with
  end
  
  def geo_distance_in_meters_from_with
    geo_circle_from_with.radius_in_meters if geo_circle_from_with
  end
  
  def geo_distance_in_meters
    self.search_options[:geo_distance] || geo_distance_in_meters_from_with
  end
  
  def geo_center
    if hash = self.search_options[:geo_center]
      Supernova::Coordinate.new(hash)
    else
      geo_center_from_with
    end
  end
  
  def geo_filed_key
    geo_filter_in_with ? geo_filter_in_with.first : :location
  end

  def q
    if self.search_options[:search].is_a?(Array)
      self.search_options[:search].map { |query| "(#{query})" }.join(" AND ")
    else
      DEFAULT_Q
    end
  end

  def sort
    convert_search_order(self.search_options[:order].join(", ")) if self.search_options[:order]
  end

  def facet_flag
    include_facets? ? true : nil
  end

  def facet_field_attributes
    self.search_options[:facets].compact.map { |field| solr_field_from_field(field) } if self.search_options[:facets]
  end

  def facet_query_attributes
    self.search_options[:facet_queries].values if self.search_options[:facet_queries]
  end

  def wt
    search_options[:wt] if search_options[:wt]
  end

  def use_pagination?
    self.search_options[:pagination] || self.search_options[:rows] || self.search_options[:start]
  end

  def rows_attribute
    self.search_options[:rows] || per_page if use_pagination?
  end

  def start_attribute
    self.search_options[:start] || current_start if use_pagination?
  end

  def current_start
    (current_page - 1) * rows_attribute
  end

  def geo_search?
    !!(geo_center && geo_distance_in_meters)
  end

  def pt
    "#{geo_center.lat},#{geo_center.lng}" if geo_search?
  end

  def d
    (geo_distance_in_meters.to_f / Supernova::KM_TO_METER) if geo_search?
  end

  def sfield
    solr_field_from_field(geo_filed_key) if geo_search?
  end
  
  # move this into separate methods (test each separatly)
  def to_params
    solr_options = {
      :fq => [], :q => q, :sort => sort, 
      :facet => facet_flag, 
      "facet.field" => facet_field_attributes,
      "facet.query" => facet_query_attributes,
      :wt => wt,
      :rows => rows_attribute,
      :start => start_attribute,
      :pt => pt,
      :d => d,
      :sfield => sfield,
    }
    solr_options[:fq] += fq_from_with(self.search_options[:with])
    if self.filters[:without]
      self.filters[:without].each do |field, values| 
        solr_options[:fq] += values.map { |value| "!#{solr_field_from_field(field)}:#{value}" }
      end
    end
    
    solr_options[:fq] << "{!geofilt}" if geo_search?
    
    if self.search_options[:select]
      self.search_options[:select] << "id" if !self.search_options[:select].map(&:to_s).include?("id")
      solr_options[:fl] = self.search_options[:select].compact.map { |field| solr_field_from_field(field) }.join(",") 
    end
    solr_options[:fq] << "type:#{self.clazz}" if self.clazz
    filter_empty_strings(solr_options)
  end

  def filter_empty_strings(params)
    params.inject({}) do |hash, (key, value)|
      hash[key] = value if !value.nil?
      hash
    end
  end
  
  def geo_filter_in_with
    (search_options[:with] || []).each do |option|
      if option.is_a?(Hash)
        option.each do |condition, value|
          return [condition.key, value] if value.is_a?(Supernova::Circle)
        end
      end
    end
    nil
  end
  
  def include_facets?
    self.search_options[:facets] || self.search_options[:facet_queries]
  end
  
  def convert_search_order(order)
    order.split(/\s*,\s*/).map do |chunk|
      if chunk.match(/(.*?) (asc|desc)/i)
        "#{solr_field_from_field($1)} #{$2}"
      else
        chunk
      end
    end.join(",")
  end
  
  def solr_field_from_field(field)
    Supernova::SolrIndexer.solr_field_for_field_name_and_mapping(field, search_options[:attribute_mapping])
  end
  
  def reverse_lookup_solr_field(solr_field)
    if search_options[:attribute_mapping]
      search_options[:attribute_mapping].each do |field, options|
        return field if solr_field.to_s == solr_field_from_field(field)
      end
    end
    solr_field
  end
  
  def fq_from_with(with)
    if with.blank?
      []
    else
      with.map do |with_part|
        if with_part.is_a?(Hash)
          with_part.map do |key_or_condition, values|
            values_from_key_or_condition_and_values(key_or_condition, values).map do |value|
              if key_or_condition.respond_to?(:solr_filter_for)
                key_or_condition.key = solr_field_from_field(key_or_condition.key)
                key_or_condition.solr_filter_for(value)
              else
                fq_filter_for_key_and_value(solr_field_from_field(key_or_condition), value)
              end
            end
          end
        else
          with_part
        end
      end.flatten
    end
  end
  
  def values_from_key_or_condition_and_values(key_or_condition, values)
    if key_or_condition.is_a?(Supernova::Condition) && values.is_a?(Array) && [:nin, :in].include?(key_or_condition.type)
      [values]
    else
      [values].flatten
    end
  end
  
  def fq_filter_for_key_and_value(key, value)
    if value.nil?
      "!#{key}:[* TO *]"
    elsif value.is_a?(Range)
      "#{key}:[#{value_for_fq_filter(value.first)} TO #{value_for_fq_filter(value.last)}]"
    else
      "#{key}:#{value_for_fq_filter(value)}"
    end
  end
  
  def value_for_fq_filter(value)
    if value.is_a?(Date)
      Time.utc(value.year, value.month, value.day).iso8601
    else
      value
    end
  end
  
  def build_docs(docs)
    docs.map do |hash|
      self.search_options[:build_doc_method] ? self.search_options[:build_doc_method].call(hash) : build_doc(hash)
    end
  end
  
  def build_doc_method(method)
    merge_search_options :build_doc_method, method
  end
  
  def build_doc(hash)
    if hash["type"].respond_to?(:constantize)
      Supernova.build_ar_like_record(hash["type"].constantize, convert_doc_attributes(hash), hash)
    else
      hash
    end
  end
  
  # called in build doc, all hashes have strings as keys!!!
  def convert_doc_attributes(hash)
    converted_hash = hash.inject({}) do |ret, (key, value)|
      if key == "id"
        ret["id"] = value.to_s.split("/").last
      else
        ret[reverse_lookup_solr_field(key).to_s] = value
      end
      ret
    end
    self.select_fields.each do |select_field|
      converted_hash[select_field.to_s] = nil if !converted_hash.has_key?(select_field.to_s)
    end
    converted_hash
  end
  
  def select_fields
    if self.search_options[:select].present?
      self.search_options[:select]
    else
      self.search_options[:named_scope_class].respond_to?(:select_fields) ? self.search_options[:named_scope_class].select_fields : []
    end
  end
  
  def format(the_format)
    merge_search_options(:wt, the_format)
  end
  
  def set_first_responding_attribute(doc, solr_key, value)
    [reverse_lookup_solr_field(solr_key), solr_key].each do |key|
      meth = :"#{key}="
      if doc.respond_to?(meth)
        doc.send(meth, value)
        return
      end
    end
  end
  
  def hashify_facets_from_response(response)
    if response["facet_counts"] && response["facet_counts"]["facet_fields"]
      response["facet_counts"]["facet_fields"].inject({}) do |hash, (key, values)|
        hash[reverse_lookup_solr_field(key)] = Hash[*values]
        hash
      end
    end
  end
  
  def typhoeus_response
    request = typhoeus_request
    request.on_complete do |response|
      log_typhoeus_response(response)
    end
    hydra.queue(request)
    hydra.run
    request.response
  end
  
  def hydra
    Typhoeus::Hydra.hydra
  end

  def qtime_from_body(body)
    if qtime_s = body[/"QTime":(\d+)/, 1]
      qtime_s.to_i
    end
  end

  def log_typhoeus_response(response)
    if Supernova.logger
      to_log = { :params => response.request.params, :host => response.request.host, :qtime => qtime_from_body(response.body) }
      Supernova.logger.info("SUPERNOVA SOLR REQUEST: #{to_log.to_json} finished in #{response.time}")
    end
  end
  
  def typhoeus_request
    Typhoeus::Request.new(select_url, :params => to_params.merge(:wt => "json"), :method => :get)
  end
  
  def execute
    collection_from_body(typhoeus_response.body)
  end
  
  def collection_from_body(body)
    collection_from_json(parse_json(body))
  end

  def parse_json(body)
    JSON.parse(body)
  rescue => err
    puts "ERROR: #{err.class} unable to parse #{body.inspect}"
    raise err
  end
  
  def collection_from_json(json)
    collection = Supernova::Collection.new(current_page, per_page == 0 ? 1 : per_page, json["response"]["numFound"])
    collection.original_criteria = self.clone
    collection.original_response = json
    collection.facets = hashify_facets_from_response(json)
    collection.replace(build_docs(json["response"]["docs"]))
    collection
  end
  
  def execute_async(&block)
    request = typhoeus_request
    request.on_complete do |response|
      log_typhoeus_response(response)
      block.call(collection_from_body(response.body))
    end
    hydra.queue(request)
  end
  
  def only_ids
    self_or_clone.except(:select).select("id")
  end
  
  def ids
    only_ids.execute.ids
  end
end
