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

  def create(instance_dir, data_dir)
    admin_action("CREATE", "name=#{name}&instanceDir=#{instance_dir}&dataDir=#{data_dir}")
  end

  def unload
    admin_action("UNLOAD", "core=#{name}&deleteIndex=true")
  end

  def status
    admin_action("STATUS", "core=#{name}")
  end

  private

  def admin_action(action, attributes)
    http_request_sync(:get, "#{solr_url}/admin/cores?action=#{action}&#{attributes}&wt=json")
  end
end
