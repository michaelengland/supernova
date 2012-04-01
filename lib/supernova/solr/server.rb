require "json"

class Supernova::Solr::Server
	attr_reader :url

	def initialize(url)
		@url = url
	end

  class << self
    def core_names(url)
      JSON.parse(Typhoeus::Request.get("#{url}/admin/cores?action=STATUS&wt=json").body)["status"].keys
    end
  end
end