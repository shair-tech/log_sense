require "bundler/gem_tasks"
task :default => :spec

require 'rake/testtask'
Rake::TestTask.new do |t|
  t.libs << 'test'
end

require_relative './lib/log_sense/ip_locator.rb'

desc "Convert Geolocation DB to sqlite (arg YYYY_MM or filename)"
task :dbip, [:filename] do |tasks, args|
  filename_or_yyyy_mm = args[:filename] || ""

  filename = if /\d{4}-\d{2}/.match(filename_or_yyyy_mm)
               "ip_locations/dbip-country-lite-#{filename_or_yyyy_mm}.csv"
             else
               filename_or_yyyy_mm
             end

  # if the filename passed as argument has a .gz extension or a gzipped version
  # of the file passed as argument exists, gunzip it
  if File.extname(filename) == ".gz" || File.exist?("#{filename}.gz")
    system "gunzip #{filename}.gz"
  end

  if File.exist? filename
    LogSense::IpLocator::dbip_to_sqlite filename
  else
    puts <<-EOS
Error. Could not find: #{filename}

I see the following files:

#{Dir.glob("ip_locations/dbip-country-lite*").map { |x| "- #{x}" }.join("\n")}

1. Download (if necessary) a more recent version from: https://db-ip.com/db/download/ip-to-country-lite
2. Save downloaded file to ip_locations/
3. Relaunch with YYYY-MM (will build: dbip-country-lite-YYYY-MM.csv)
   or with filename.

Remark. If the filename has the extension .gz or if the filename does not exist,
but a file with the same name and .gz extension exists, it is gunzipped first
    EOS

    exit
  end
end
