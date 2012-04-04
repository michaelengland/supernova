require "supernova/solr_criteria"

module Supernova::Solr
  class ConnectionDummy
    def add(row)
      deprication_warning("add")
      Supernova::Solr.add(row)
    end
    
    def commit
      deprication_warning("commit!")
      Supernova::Solr.commit!
    end
    
    def deprication_warning(instead)
      puts "DEPRICATION WARNING: calling #{caller.first[/\`(.*?)\'/, 1]} is depricated. Use Supernova::Solr.#{instead} instead. Called from #{filter_callers(caller).at(1)}"
    end
    
    def filter_callers(callers)
      callers.reject { |c| c.include?("/gems/")}
    end
  end
  
  class << self
    attr_accessor :url

    def remove_trailing_slash(url)
      url.gsub(/[\/]+$/, "")
    end
    
    def select_url
      "#{url}/select"
    end
    
    def connection
      ConnectionDummy.new
    end
    
    def update_request(payload)
      Typhoeus::Request.post("#{url}/update", 
        :body => %(<?xml version="1.0" encoding="UTF-8"?>#{payload}), :headers => { "Content-Type" => "text/xml"}
      )
    end
    
    def truncate!
      update_request("<delete><query>*:*</query></delete>")
    end
    
    def commit!
      update_request("<commit />")
    end
    
    # only to be used for testing
    def add(row)
      Supernova::SolrIndexer.new.index_with_json([row])
    end
  end
  
  def self.included(base)
    base.extend(Supernova::ClassMethods)
    base.criteria_class = Supernova::SolrCriteria
  end
end

require "supernova/solr_indexer"