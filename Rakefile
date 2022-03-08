require "bundler/gem_tasks"
task :default => :spec

require 'rake/testtask'
Rake::TestTask.new do |t|
  t.libs << 'test'
end

require_relative './lib/log_sense/ip_locator.rb'

desc "Convert Geolocation DB to sqlite"
task :dbip_to_sqlite3, [:year_month] do |tasks, args|
  filename = "./ip_locations/dbip-country-lite-#{args[:year_month]}.csv"

  if !File.exist? filename
    puts "Error. Could not find: #{filename}"
    puts
    puts 'I see the following files:'
    puts Dir.glob("ip_locations/dbip-country-lite*").map { |x| "- #{x}\n" }
    puts ''
    puts '1. Download (if necessary) a more recent version from: https://db-ip.com/db/download/ip-to-country-lite'
    puts '2. Save downloaded file to ip_locations/'
    puts '3. Relaunch with YYYY-MM'

    exit
  else
    LogSense::IpLocator::dbip_to_sqlite filename
  end
end
