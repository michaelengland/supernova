$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib/supernova'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require File.expand_path("../../lib/supernova.rb", __FILE__)
require "logger"
require "fileutils"
require "ruby-debug"
require "geokit"

def project_root
  Pathname.new(File.expand_path("..", File.dirname(__FILE__)))
end

if defined?(Debugger) && Debugger.respond_to?(:settings)
  Debugger.settings[:autolist] = 1
  Debugger.settings[:autoeval] = true
end

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.before(:each) do
    Supernova::Criteria.mutable_by_default!
  end

  config.after(:each) do
    Supernova::Solr.url = nil
  end
end

FileUtils.mkdir_p(project_root.join("log"))

class Host
  attr_accessor :id
end