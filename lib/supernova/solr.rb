module Supernova::Solr
  class << self
    attr_accessor :url
    attr_writer :read_url
    alias_method :write_url, :url

    def read_url
      @read_url || url
    end

    def remove_trailing_slash(url)
      url.gsub(/[\/]+$/, "")
    end
    
    def select_url
      "#{url}/select"
    end
  end
  
  def self.included(base)
    base.extend(Supernova::ClassMethods)
    base.criteria_class = Supernova::SolrCriteria
  end
end

require "supernova/solr_criteria"
require "supernova/solr_indexer"
