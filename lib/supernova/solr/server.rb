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
    JSON.parse(http_get("#{url}/admin/cores?action=STATUS&wt=json").body)["status"].keys
  end

  def index_docs(docs, commit = false)
    body = docs.map { |doc| %({"add":) + { :doc => doc }.to_json + "}" }.join("\n")
    post_update(url, body, commit)
  end

  def select(params = {})
    JSON.parse(select_raw(params).body)
  end

  def select_raw(params = {})
    get(url, "select", :params => DEFAULT_PARAMS.merge(params))
  end

  def commit
    post_update(url, { "commit" => {} }.to_json)
  end

  def optimize
    post_update(url, { "optimize" => {} }.to_json)
  end

  def delete_by_query(query, commit = false)
    post_update(url, { "delete" => { "query" => query }}.to_json, commit)
  end

  def truncate(commit = false)
    delete_by_query("*:*", commit)
  end

  private

  def get(solr_url, relative_path, attributes = {})
    http_get("#{solr_url}/#{relative_path}", attributes)
  end

  def post_update(core_url, body, commit = false)
    url = "#{core_url}/update/json"
    if commit.is_a?(Numeric)
      url << "?commitWithin=#{commit}" 
    elsif commit
      url << "?commit=true" 
    end
    Typhoeus::Request.post(url, :headers => { "Content-Type" => "application/json" }, :body => body)
  end

  def http_get(url, attributes = {})
    Typhoeus::Request.get(url, attributes)
  end
end
