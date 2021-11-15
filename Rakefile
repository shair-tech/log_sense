require "bundler/gem_tasks"
task :default => :spec

require 'rake/testtask'
Rake::TestTask.new do |t|
  t.libs << 'test'
end

require_relative './lib/log_sense/ip_locator.rb'

desc "Convert Geolocation DB to sqlite"
task :dbip_to_sqlite3, [:filename] do |tasks, args|
  filename = args[:filename]
  ApacheLogReport::IpLocator::dbip_to_sqlite filename
end
