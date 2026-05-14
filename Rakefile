# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec) do |task|
  task.exclude_pattern = "spec/lxdb/integration/**/*_spec.rb"
end
RSpec::Core::RakeTask.new(integration: :enable_integration_specs) do |task|
  task.pattern = "spec/lxdb/integration/**/*_spec.rb"
end

task test: :spec
task :enable_integration_specs do
  ENV["LXDB_INTEGRATION"] ||= "1"
end

task ci: %i[spec integration]
task default: %i[spec]
