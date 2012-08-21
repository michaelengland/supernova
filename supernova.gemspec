# -*- encoding: utf-8 -*-
require File.expand_path('../lib/supernova/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Tobias Schwab"]
  gem.email         = ["tobias.schwab@dynport.de"]
  gem.description   = %q{Supernova}
  gem.summary       = %q{Yet another SOLR library.}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "supernova"
  gem.require_paths = ["lib"]
  gem.add_runtime_dependency("typhoeus")
  gem.add_runtime_dependency("activesupport",">=3.0.0")
  gem.add_runtime_dependency("will_paginate")
  gem.add_runtime_dependency("json")
  gem.add_development_dependency('activerecord', ">=3.0.0")
  gem.add_development_dependency("mysql2")
  gem.add_development_dependency("debugger")
  gem.add_development_dependency("geokit")
  gem.add_development_dependency("guard", "1.3.2")
  gem.add_development_dependency("rb-fsevent", "0.9.1")
  gem.add_development_dependency("growl", "1.0.3")
  gem.add_development_dependency("rspec", "~> 2.11.0")
  gem.add_development_dependency("webmock")
  gem.add_development_dependency("foreman")
  gem.add_development_dependency("rake")
  gem.version       = Supernova::VERSION
end
