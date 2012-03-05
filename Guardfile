# A sample Guardfile
# More info at https://github.com/guard/guard#readme

require "rubygems"
require "guard/guard"

guard :bundler do
  watch('Gemfile')
end

def spec_helper_cmd
  "-r ./spec/spec_helper.rb" if File.exists?(File.expand_path("../spec/spec_helper.rb", __FILE__))
end

guard 'rspec', :version => 2, :cli => "#{spec_helper_cmd} --color -t wip", :notification => :growl do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})     { |m| ["spec/lib/#{m[1]}_spec.rb", "spec/#{m[1]}_spec.rb"] }
  watch('spec/spec_helper.rb')  { "spec" }

  # Rails example
  watch(%r{^app/(.+)\.rb$})                           { |m| "spec/#{m[1]}_spec.rb" }
  watch(%r{^app/(.*)(\.erb|\.haml)$})                 { |m| "spec/#{m[1]}#{m[2]}_spec.rb" }
  watch(%r{^app/controllers/(.+)_(controller)\.rb$})  { |m| ["spec/routing/#{m[1]}_routing_spec.rb", "spec/#{m[2]}s/#{m[1]}_#{m[2]}_spec.rb", "spec/acceptance/#{m[1]}_spec.rb"] }
  watch(%r{^spec/support/(.+)\.rb$})                  { "spec" }
  watch('config/routes.rb')                           { "spec/routing" }
  watch('app/controllers/application_controller.rb')  { "spec/controllers" }
  # Capybara request specs
  watch(%r{^app/views/(.+)/.*\.(erb|haml)$})          { |m| "spec/requests/#{m[1]}_spec.rb" }
end