require "spec_helper"
require "active_record"

ActiveRecord::Base.establish_connection(
  :adapter => "mysql2",
  :host => "localhost", 
  :database => "supernova_test", 
  :username => "root",
  :encoding => "utf8"
)

ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS offers")
ActiveRecord::Base.connection.execute("CREATE TABLE offers (id SERIAL, text TEXT, user_id INTEGER, enabled BOOLEAN, popularity INTEGER, lat FLOAT, lng FLOAT)")

class Offer < ActiveRecord::Base
  include Supernova::Solr
  named_search_scope :for_user_ids do |*ids|
    with(:user_id => ids.flatten)
  end
end

RSpec.configure do |config|
  config.before(:each) do
    ActiveRecord::Base.connection.execute("TRUNCATE offers")
  end
end
