require "optparse"
require "optparse/date"
require "log_sense/version"
require "log_sense/options_checker"

module LogSense
  module OptionsParser
    #
    # parse command line options
    #
    def self.parse(options)
      limit = 100
      args = {}

      opt_parser = OptionParser.new do |opts|
        opts.banner = "Usage: log_sense [options] [logfile ...]"

        opts.on("-tTITLE", "--title=TITLE",
                String,
                "Title to use in the report") do |optval|
          args[:title] = optval
        end

        opts.on("-fFORMAT", "--input-format=FORMAT",
                String,
                "Input format (either rails or apache)") do |optval|
          args[:input_format] = optval
        end

        opts.on("-iFORMAT", "--input-files=file,file,",
                Array,
                "Input files (can also be passed directly)") do |optval|
          args[:input_filenames] = optval
        end

        opts.on("-tFORMAT", "--output-format=FORMAT",
                String,
                "Output format: html, org, txt, sqlite.") do |optval|
          args[:output_format] = optval
        end

        opts.on("-oOUTPUT_FILE", "--output-file=OUTPUT_FILE",
                String,
                "Output file") do |n|
          args[:output_filename] = n
        end

        opts.on("-bDATE", "--begin=DATE",
                Date,
                "Consider entries after or on DATE") do |optval|
          args[:from_date] = optval
        end

        opts.on("-eDATE", "--end=DATE",
                Date,
                "Consider entries before or on DATE") do |optval|
          args[:to_date] = optval
        end

        opts.on("-lN", "--limit=N",
                Integer,
                "Limit to the N most requested resources (defaults to #{limit})") do |optval|
          args[:limit] = optval
        end

        opts.on("-wWIDTH", "--width=WIDTH",
                Integer,
                "Maximum width of long columns in textual reports") do |optval|
          args[:width] = optval
        end

        opts.on("-rROWS", "--rows=ROWS",
                Integer,
                "Maximum number of rows for columns with multiple entries in textual reports") do |optval|
          args[:inner_rows] = optval
        end

        opts.on("-pPATTERN", "--pattern=PATTERN",
                String,
                "Pattern to use with ufw report to decide IP to blacklist") do |optval|
          args[:pattern] = optval
        end

        opts.on("-cPOLICY", "--crawlers=POLICY",
                String,
                "Decide what to do with crawlers (applies to Apache Logs)") do |optval|
          case optval
          when "only"
            args[:only_crawlers] = true
          when "ignore"
            args[:ignore_crawlers] = true
          end
        end

        opts.on("-ns", "--no-selfpoll",
                "Ignore self poll entries (requests from ::1; applies to Apache Logs)") do
          args[:no_selfpoll] = true
        end

        opts.on("-ng", "--no-geo",
                "Do not geolocate entries") do
          args[:geolocation] = false
        end

        opts.on("--verbose", "Inform about progress (output to STDERR)") do
          args[:verbose] = true
        end

        opts.on("-v", "--version", "Prints version information") do
          puts "log_sense version #{LogSense::VERSION}"
          puts "Copyright (C) 2021 Shair.Tech"
          puts "Distributed under the terms of the MIT license"
          exit
        end

        opts.on("-h", "--help", "Prints this help") do
          puts opts
          puts
          puts "This is version #{LogSense::VERSION}"

          puts
          puts "Output formats:"
          puts

          puts OptionsChecker.chains_to_s

          exit 0
        end
      end

      opt_parser.parse!(options)

      args[:limit] ||= limit
      args[:input_filenames] ||= []
      args[:input_format] ||= "apache"
      args[:output_format] ||= "html"
      args[:ignore_crawlers] ||= false
      args[:only_crawlers] ||= false
      args[:no_selfpoll] ||= false
      args[:verbose] ||= false
      # if set to false leave, otherwise set to true
      args[:geolocation] = true unless args[:geolocation] == false

      args
    end
  end
end
