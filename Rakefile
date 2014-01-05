#!/usr/bin/env rake

require 'rake'
require 'rake/tasklib'
require 'rake/testtask'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new do |t|
  t.rspec_opts = '--default_path test/unit'
end

require 'kitchen/rake_tasks'
Kitchen::RakeTasks.new

# aliases
task :test => :spec
task :default => [:test]
task :all => [:test, 'kitchen:all']
