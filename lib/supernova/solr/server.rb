require "json"
require "supernova/solr"

class Supernova::Solr::Server
  attr_reader :url

  def initialize(url)
    @url = Supernova::Solr.remove_trailing_slash(url)
  end

  DEFAULT_PARAMS = {
    :q => "*:*", :wt => "json"
  }

  def core_names
    parse_json(http_request_sync(:get, "#{url}/admin/cores?action=STATUS&wt=json").body)["status"].keys
  end

  def select(params = {})
    response = nil
    select_async(params) do |the_response|
      response = the_response
    end
    run
    response
  end

  def select_async(params = {}, &block)
    http_request_async(:get, "#{url}/select", :params => DEFAULT_PARAMS.merge(params)) do |response|
      yield(parse_json(response.body))
    end
  end

  def index_docs(docs, commit = false)
    body = docs.map { |doc| %({"add":) + { :doc => doc }.to_json + "}" }.join("\n")
    post_update(body, commit)
  end

  def commit
    post_update({ "commit" => {} }.to_json)
  end

  def optimize
    post_update({ "optimize" => {} }.to_json)
  end

  def delete_by_query(query, commit = false)
    post_update({ "delete" => { "query" => query }}.to_json, commit)
  end

  def truncate(commit = false)
    delete_by_query("*:*", commit)
  end

  def run
    hydra.run
  end

  private

  def parse_json(raw)
    JSON.parse(raw)
  end

  def select_raw(params = {})
    http_request_sync(:get, "#{url}/select", :params => DEFAULT_PARAMS.merge(params))
  end

  def post_update(body, commit = false)
    http_request_sync(:post, update_url_with_commit(commit), :headers => { "Content-Type" => "application/json" }, :body => body)
  end

  def update_url_with_commit(commit = false)
    return "#{update_url}?commitWithin=#{commit}" if commit.is_a?(Numeric)
    return "#{update_url}?commit=true" if commit == true
    update_url
  end

  def update_url
    "#{url}/update/json"
  end

  def http_request_sync(method, url, attributes = {})
    request = http_request_async(method, url, attributes)
    run
    request.response
  end

  def http_request_async(method, url, attributes = {}, &block)
    request = Typhoeus::Request.new(url, attributes.merge(method: method))
    request.on_complete do |response|
      log_typhoeus_response(response)
      yield(response) if block_given?
    end
    hydra.queue(request)
    request
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
  

  def hydra
    Typhoeus::Hydra.hydra
  end
end
