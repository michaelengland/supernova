# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "supernova"
  s.version = "0.7.5"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Tobias Schwab"]
  s.date = "2012-02-21"
  s.description = "Unified search scopes"
  s.email = "tobias.schwab@dynport.de"
  s.executables = ["start_solr"]
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc",
    "TODO"
  ]
  s.files = [
    ".autotest",
    ".document",
    ".rspec",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE.txt",
    "README.rdoc",
    "Rakefile",
    "TODO",
    "VERSION",
    "autotest/discover.rb",
    "bin/start_solr",
    "lib/supernova.rb",
    "lib/supernova/collection.rb",
    "lib/supernova/condition.rb",
    "lib/supernova/criteria.rb",
    "lib/supernova/numeric_extensions.rb",
    "lib/supernova/solr.rb",
    "lib/supernova/solr_criteria.rb",
    "lib/supernova/solr_indexer.rb",
    "lib/supernova/symbol_extensions.rb",
    "solr/conf/admin-extra.html",
    "solr/conf/elevate.xml",
    "solr/conf/mapping-FoldToASCII.txt",
    "solr/conf/mapping-ISOLatin1Accent.txt",
    "solr/conf/protwords.txt",
    "solr/conf/schema.xml",
    "solr/conf/scripts.conf",
    "solr/conf/solrconfig.xml",
    "solr/conf/spellings.txt",
    "solr/conf/stopwords.txt",
    "solr/conf/synonyms.txt",
    "solr/conf/velocity/VM_global_library.vm",
    "solr/conf/velocity/browse.vm",
    "solr/conf/velocity/cluster.vm",
    "solr/conf/velocity/clusterResults.vm",
    "solr/conf/velocity/doc.vm",
    "solr/conf/velocity/facet_dates.vm",
    "solr/conf/velocity/facet_fields.vm",
    "solr/conf/velocity/facet_queries.vm",
    "solr/conf/velocity/facet_ranges.vm",
    "solr/conf/velocity/facets.vm",
    "solr/conf/velocity/footer.vm",
    "solr/conf/velocity/head.vm",
    "solr/conf/velocity/header.vm",
    "solr/conf/velocity/hit.vm",
    "solr/conf/velocity/jquery.autocomplete.css",
    "solr/conf/velocity/jquery.autocomplete.js",
    "solr/conf/velocity/layout.vm",
    "solr/conf/velocity/main.css",
    "solr/conf/velocity/query.vm",
    "solr/conf/velocity/querySpatial.vm",
    "solr/conf/velocity/suggest.vm",
    "solr/conf/velocity/tabs.vm",
    "solr/conf/xslt/example.xsl",
    "solr/conf/xslt/example_atom.xsl",
    "solr/conf/xslt/example_rss.xsl",
    "solr/conf/xslt/luke.xsl",
    "solr/start.rb",
    "spec/database.sql",
    "spec/integration/solr_spec.rb",
    "spec/spec_helper.rb",
    "spec/supernova/collection_spec.rb",
    "spec/supernova/condition_spec.rb",
    "spec/supernova/criteria_spec.rb",
    "spec/supernova/numeric_extensions_spec.rb",
    "spec/supernova/solr_criteria_spec.rb",
    "spec/supernova/solr_indexer_spec.rb",
    "spec/supernova/solr_spec.rb",
    "spec/supernova/symbol_extensions_spec.rb",
    "spec/supernova_spec.rb",
    "supernova.gemspec"
  ]
  s.homepage = "http://github.com/dynport/supernova"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.10"
  s.summary = "Unified search scopes"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<will_paginate>, [">= 0"])
      s.add_runtime_dependency(%q<json>, [">= 0"])
      s.add_runtime_dependency(%q<activesupport>, [">= 0"])
      s.add_runtime_dependency(%q<typhoeus>, ["= 0.3.3"])
      s.add_development_dependency(%q<i18n>, [">= 0"])
      s.add_development_dependency(%q<activerecord>, ["~> 3.0.7"])
      s.add_development_dependency(%q<ruby-debug19>, [">= 0"])
      s.add_development_dependency(%q<mysql2>, ["~> 0.2.18"])
      s.add_development_dependency(%q<ZenTest>, ["= 4.5.0"])
      s.add_development_dependency(%q<geokit>, [">= 0"])
      s.add_development_dependency(%q<guard>, [">= 0"])
      s.add_development_dependency(%q<rb-fsevent>, [">= 0"])
      s.add_development_dependency(%q<growl>, [">= 0"])
      s.add_development_dependency(%q<growl_notify>, [">= 0"])
      s.add_development_dependency(%q<autotest>, [">= 0"])
      s.add_development_dependency(%q<autotest-growl>, [">= 0"])
      s.add_development_dependency(%q<rspec>, ["~> 2.8.0"])
      s.add_development_dependency(%q<bundler>, ["~> 1.0.0"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.6.0"])
      s.add_development_dependency(%q<rcov>, [">= 0"])
    else
      s.add_dependency(%q<will_paginate>, [">= 0"])
      s.add_dependency(%q<json>, [">= 0"])
      s.add_dependency(%q<activesupport>, [">= 0"])
      s.add_dependency(%q<typhoeus>, ["= 0.3.3"])
      s.add_dependency(%q<i18n>, [">= 0"])
      s.add_dependency(%q<activerecord>, ["~> 3.0.7"])
      s.add_dependency(%q<ruby-debug19>, [">= 0"])
      s.add_dependency(%q<mysql2>, ["~> 0.2.18"])
      s.add_dependency(%q<ZenTest>, ["= 4.5.0"])
      s.add_dependency(%q<geokit>, [">= 0"])
      s.add_dependency(%q<guard>, [">= 0"])
      s.add_dependency(%q<rb-fsevent>, [">= 0"])
      s.add_dependency(%q<growl>, [">= 0"])
      s.add_dependency(%q<growl_notify>, [">= 0"])
      s.add_dependency(%q<autotest>, [">= 0"])
      s.add_dependency(%q<autotest-growl>, [">= 0"])
      s.add_dependency(%q<rspec>, ["~> 2.8.0"])
      s.add_dependency(%q<bundler>, ["~> 1.0.0"])
      s.add_dependency(%q<jeweler>, ["~> 1.6.0"])
      s.add_dependency(%q<rcov>, [">= 0"])
    end
  else
    s.add_dependency(%q<will_paginate>, [">= 0"])
    s.add_dependency(%q<json>, [">= 0"])
    s.add_dependency(%q<activesupport>, [">= 0"])
    s.add_dependency(%q<typhoeus>, ["= 0.3.3"])
    s.add_dependency(%q<i18n>, [">= 0"])
    s.add_dependency(%q<activerecord>, ["~> 3.0.7"])
    s.add_dependency(%q<ruby-debug19>, [">= 0"])
    s.add_dependency(%q<mysql2>, ["~> 0.2.18"])
    s.add_dependency(%q<ZenTest>, ["= 4.5.0"])
    s.add_dependency(%q<geokit>, [">= 0"])
    s.add_dependency(%q<guard>, [">= 0"])
    s.add_dependency(%q<rb-fsevent>, [">= 0"])
    s.add_dependency(%q<growl>, [">= 0"])
    s.add_dependency(%q<growl_notify>, [">= 0"])
    s.add_dependency(%q<autotest>, [">= 0"])
    s.add_dependency(%q<autotest-growl>, [">= 0"])
    s.add_dependency(%q<rspec>, ["~> 2.8.0"])
    s.add_dependency(%q<bundler>, ["~> 1.0.0"])
    s.add_dependency(%q<jeweler>, ["~> 1.6.0"])
    s.add_dependency(%q<rcov>, [">= 0"])
  end
end

