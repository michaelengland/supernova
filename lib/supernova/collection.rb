require "will_paginate"

class Supernova::Collection < WillPaginate::Collection
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
end