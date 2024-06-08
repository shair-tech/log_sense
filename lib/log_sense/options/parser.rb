# frozen_string_literal: true

require "optparse"
require "optparse/date"
require "log_sense/version"
require "log_sense/options/checker"

module LogSense
  #
  # Parse command line options
  #
  module Options
    module Parser
      #
      # parse command line options
      #
      def self.parse(options)
        # Defaults
        args = {
          geolocation: true,
          ignore_crawlers: false,
          input_filenames: [],
          input_format: "apache",
          limit: 100,
          no_selfpoll: false,
          only_crawlers: false,
          output_format: "html",
          pattern: "php",
          verbose: false,
        }

        opt_parser = OptionParser.new do |opts|
          opts.banner = "Usage: log_sense [options] [logfile ...]"

          opts.on(
            "-tTITLE", "--title=TITLE",
            String,
            "Title to use in the report") do |optval|
            args[:title] = optval
          end

          opts.on(
            "-fFORMAT", "--input-format=FORMAT",
            String,
            "Input format: rails or apache #{dft(args[:input_format])}") do |optval|
            args[:input_format] = optval
          end

          opts.on(
            "-iFORMAT", "--input-files=file,file,",
            Array,
            "Input files (can also be passed as arguments)") do |optval|
            args[:input_filenames] = optval
          end

          opts.on(
            "-tFORMAT", "--output-format=FORMAT",
            String,
            "Output format: html, org, txt, sqlite #{dft(args[:output_format])}") do |optval|
            args[:output_format] = optval
          end

          opts.on(
            "-oOUTPUT_FILE", "--output-file=OUTPUT_FILE",
            String,
            "Output file. #{dft('STDOUT')}") do |n|
            args[:output_filename] = n
          end

          opts.on(
            "-bDATE", "--begin=DATE",
            Date,
            "Consider only entries after or on DATE") do |optval|
            args[:from_date] = optval
          end

          opts.on(
            "-eDATE", "--end=DATE",
            Date,
            "Consider only entries before or on DATE") do |optval|
            args[:to_date] = optval
          end

          opts.on(
            "-lN", "--limit=N",
            Integer,
            "Limit to the N most requested resources #{dft(args[:limit])}") do |optval|
            args[:limit] = optval
          end

          opts.on(
            "-wWIDTH", "--width=WIDTH",
            Integer,
            "Maximum width of long columns in textual reports") do |optval|
            args[:width] = optval
          end

          opts.on(
            "-rROWS", "--rows=ROWS",
            Integer,
            "Maximum number of rows for columns with multiple entries in textual reports") do |optval|
            args[:inner_rows] = optval
          end

          opts.on(
            "-pPATTERN", "--pattern=PATTERN",
            String,
            "Pattern to use with ufw report to select IP to blacklist #{dft(args[:pattern])}") do |optval|
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

          opts.on(
            "--no-selfpoll",
            "Ignore self poll entries (requests from ::1; applies to Apache Logs) #{dft(args[:no_selfpoll])}") do
            args[:no_selfpoll] = true
          end

          opts.on("--no-geo",
                  "Do not geolocate entries #{dft(args[:geolocation])}") do
            args[:geolocation] = false
          end

          opts.on(
            "--verbose",
            "Inform about progress (output to STDERR) #{dft(args[:verbose])}") do
            args[:verbose] = true
          end

          opts.on("-v", "--version", "Prints version information") do
            puts "log_sense version #{LogSense::VERSION}"
            puts "Copyright (C) 2021-2024 Shair.Tech"
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
            puts Options::Checker.chains_to_s

            exit 0
          end
        end

        opt_parser.parse!(options)

        args
      end

      def self.dft(value)
        "(DEFAULT: #{value})"
      end
    end
  end
end
