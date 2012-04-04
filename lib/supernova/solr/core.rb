require "typhoeus"
require "json"

class Supernova::Solr::Core
  attr_reader :solr_url, :name

  class << self
    # class Page
    #   attr_reader :url, :protocol
    #
    #   def initialize(url, protocol)
    #     @url = url
    #     @protocol = protocol
    #   end
    #
    #   def self.get(url)
    #     Net::HTTP.get(URI.parse(url))
    #   end
    #
    #   def self.post(url, body)
    #     Net::HTTP.post(URI.parse(url))
    #   end
    #
    #   def self.head(url, protocol)
    #     Net::HTTP.head(URI.parse(url), protocol)
    #   end
    #
    #   functional_delegate :get, :post,  :attributes => :url
    #   functional_delegate :head,        :attributes => [:url, :protocol]
    # end
    #
    # Page.new("http://www.dynport.de").get                # delegates to Page.get("http://www.dynport.de")
    # Page.new("http://www.dynport.de").post("the body")   # delegates to Page.post("http://www.dynport.de", "the body")
    # Page.new("http://www.dynport.de", "HTTP/1.1").head   # delegates to Page.head("http://www.dynport.de", "HTTP/1.1")

    def functional_delegate(*keys)
      raise "ERROR: last argument must be e.g. :attributes => [:url]" if !keys.last.is_a?(Hash) || !keys.last.has_key?(:attributes)
      keys[0..-2].each do |method|
        define_method(method) do |*args|
          all_args = [keys.last[:attributes]].flatten.map { |att| self.send(att) } + args
          self.class.send(method, *all_args)
        end
      end
    end
  end

  def initialize(solr_url = nil, name = nil)
    @solr_url = solr_url.gsub(/[\/]+$/, "")
    @name = name
  end

  def url
    "#{solr_url}/#{name}"
  end

  functional_delegate :commit, :index_docs, :commit, :optimize, :delete_by_query, :truncate, :attributes => :url
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

    def index_docs(core_url, docs, commit = false)
      body = docs.map { |doc| %({"add":) + { :doc => doc }.to_json + "}" }.join("\n")
      post_update(core_url, body, commit)
    end

    DEFAULT_PARAMS = {
      :q => "*:*", :wt => "json"
    }

    def select(core_url, params = {})
      Typhoeus::Request.get("#{core_url}/select", :params => DEFAULT_PARAMS.merge(params))
    end

    def commit(core_url)
      post_update(core_url, { "commit" => {} }.to_json)
    end

    def optimize(core_url)
      post_update(core_url, { "optimize" => {} }.to_json)
    end

    def delete_by_query(core_url, query, commit = false)
      post_update(core_url, { "delete" => { "query" => query }}.to_json, commit)
    end

    def truncate(core_url, commit = false)
      delete_by_query(core_url, "*:*", commit)
    end

    private

    def post_update(core_url, body, commit = false)
      url = "#{core_url}/update/json"
      if commit.is_a?(Numeric)
        url << "?commitWithin=#{commit}" 
      elsif commit
        url << "?commit=true" 
      end
      Typhoeus::Request.post(url, :headers => { "Content-Type" => "application/json" }, :body => body)
    end

    def admin_action(solr_url, action, attributes)
      Typhoeus::Request.get("#{solr_url}/admin/cores?action=#{action}&#{attributes}&wt=json")
    end
  end
end