require "supernova/solr/server"
require "typhoeus"
require "json"

class Supernova::Solr::Core < Supernova::Solr::Server
  attr_reader :solr_url, :name

  def initialize(solr_url, name)
    @solr_url = Supernova::Solr.remove_trailing_slash(solr_url)
    @name = name
  end

  def url
    "#{solr_url}/#{name}"
  end

  functional_delegate :create, :unload, :status, :attributes => [:solr_url, :name]

  class << self
    def create(solr_url, core_name, instance_dir, data_dir)
      admin_action(solr_url, "CREATE", "name=#{core_name}&instanceDir=#{instance_dir}&dataDir=#{data_dir}")
    end

    def unload(solr_url, core_name)
      admin_action(solr_url, "UNLOAD", "core=#{core_name}&deleteIndex=true")
    end

    def status(solr_url, core_name)
      admin_action(solr_url, "STATUS", "core=#{core_name}")
    end

    private

    def admin_action(solr_url, action, attributes)
      http_get("#{solr_url}/admin/cores?action=#{action}&#{attributes}&wt=json")
    end
  end
end
