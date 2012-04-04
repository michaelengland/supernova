require "json"

class Supernova::Solr::Server
	attr_reader :url

	def initialize(url)
		@url = Supernova::Solr.remove_trailing_slash(url)
	end

  class << self
    def core_names(url)
      JSON.parse(Typhoeus::Request.get("#{url}/admin/cores?action=STATUS&wt=json").body)["status"].keys
    end
  end
end