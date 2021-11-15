require 'optparse'
require 'optparse/date'
require 'apache_log_report/version'

module LogSense
  module OptionsParser
    #
    # parse command line options
    #
    def self.parse options
      limit = 30
      args = {} 

      opt_parser = OptionParser.new do |opts|
        opts.banner = "Usage: log_sense [options] [logfile]"

        opts.on("-fFORMAT", "--from=FORMAT", String, "Input format (either rails or apache)") do |n|
          args[:input_format] = n
        end

        opts.on("-iINPUT_FILE", "--input=INPUT_FILE", String, "Input file") do |n|
          args[:input_file] = n
        end

        opts.on("-tFORMAT", "--to=FORMAT", String, "Output format: html, org, txt, sqlite. Defaults to org mode") do |n|
          args[:output_format] = n
        end

        opts.on("-oOUTPUT_FILE", "--output=OUTPUT_FILE", String, "Output file") do |n|
          args[:output_file] = n
        end

        opts.on("-bDATE", "--begin=DATE", Date, "Consider entries after or on DATE") do |n|
          args[:from_date] = n
        end

        opts.on("-eDATE", "--end=DATE", Date, "Consider entries before or on DATE") do |n|
          args[:to_date] = n
        end

        opts.on("-lN", "--limit=N", Integer, "Number of entries to show (defaults to #{limit})") do |n|
          args[:limit] = n
        end

        opts.on("-cPOLICY", "--crawlers=POLICY", String, "Decide what to do with crawlers (applies to Apache Logs)") do |n|
          case n
          when 'only'
            args[:only_crawlers] = true
          when 'ignore'
            args[:ignore_crawlers] = true
          end
        end

        opts.on("-ns", "--no-selfpoll", "Ignore self poll entries (requests from ::1; applies to Apache Logs)") do
          args[:no_selfpoll] = true
        end

        opts.on("-v", "--version", "Prints version information") do
          puts "log_sense version #{LogSense::VERSION}"
          puts "Copyright (C) 2020 Adolfo Villafiorita"
          puts "Distributed under the terms of the MIT license"
          puts ""
          puts "Written by Adolfo Villafiorita"
          exit
        end

        opts.on("-h", "--help", "Prints this help") do
          puts opts
          puts "This is version #{LogSense::VERSION}"
          exit
        end
      end

      opt_parser.parse!(options)

      args[:limit] ||= limit
      args[:input_format] ||= "apache"
      args[:output_format] ||= "html"
      args[:ignore_crawlers] ||= false
      args[:only_crawlers] ||= false
      args[:no_selfpoll] ||= false

      return args
    end
  end
end
