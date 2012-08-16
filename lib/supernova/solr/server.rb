require "json"

class Supernova::Solr::Server
  attr_reader :url

  def initialize(url)
    @url = Supernova::Solr.remove_trailing_slash(url)
  end

  DEFAULT_PARAMS = {
    :q => "*:*", :wt => "json"
  }

  def core_names
    parse_json(http_request(:get, "#{url}/admin/cores?action=STATUS&wt=json").body)["status"].keys
  end

  def select(params = {})
    parse_json(select_raw(params).body)
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

  private

  def parse_json(raw)
    JSON.parse(raw)
  end

  def select_raw(params = {})
    http_request(:get, "#{url}/select", :params => DEFAULT_PARAMS.merge(params))
  end

  def post_update(body, commit = false)
    http_request(:post, update_url_with_commit(commit), :headers => { "Content-Type" => "application/json" }, :body => body)
  end

  def update_url_with_commit(commit = false)
    return "#{update_url}?commitWithin=#{commit}" if commit.is_a?(Numeric)
    return "#{update_url}?commit=true" if commit == true
    update_url
  end

  def update_url
    "#{url}/update/json"
  end

  def http_request(method, url, attributes = {})
    request = Typhoeus::Request.new(url, attributes.merge(method: method))
    hydra.queue(request)
    hydra.run
    request.response
  end

  def hydra
    Typhoeus::Hydra.hydra
  end
end
