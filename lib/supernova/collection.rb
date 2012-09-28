require 'kaminari'
require 'kaminari/models/array_extension'

class Supernova::Collection < Kaminari::PaginatableArray
  attr_accessor :original_response, :facets, :original_criteria
  
  def raw_facet_queries
    raw_facet_counts["facet_queries"] || {}
  end
  
  def raw_facet_counts
    original_response["facet_counts"] || {}
  end
  
  def facet_queries
    @facet_queries ||= raw_facet_queries.inject({}) do |hash, (raw_query, count)|
      hash[original_facet_queries.invert[raw_query]] = count
      hash
    end
  end
  
  def original_facet_queries
    original_criteria.search_options[:facet_queries] || {}
  end
  
  def ids
    @ids ||= extract_ids_from_solr_hash(original_response)
  end
  
  def extract_ids_from_solr_hash(solr_hash)
    col = self.dup
    col.replace(solr_hash["response"]["docs"].map { |hash| hash["id"][/(\d+)$/, 1].to_i })
    col
  end
end
