require 'optparse'
require 'optparse/date'
require 'log_sense/version'

module LogSense
  module OptionsParser
    #
    # parse command line options
    #
    def self.parse(options)
      limit = 900
      args = {} 

      opt_parser = OptionParser.new do |opts|
        opts.banner = 'Usage: log_sense [options] [logfile ...]'

        opts.on('-tTITLE', '--title=TITLE', String, 'Title to use in the report') do |n|
          args[:title] = n
        end

        opts.on('-fFORMAT', '--input-format=FORMAT', String, 'Input format (either rails or apache)') do |n|
          args[:input_format] = n
        end

        opts.on('-tFORMAT', '--output-format=FORMAT', String, 'Output format: html, org, txt, sqlite. See below for available formats') do |n|
          args[:output_format] = n
        end

        opts.on('-oOUTPUT_FILE', '--output-file=OUTPUT_FILE', String, 'Output file') do |n|
          args[:output_file] = n
        end

        opts.on('-bDATE', '--begin=DATE', Date, 'Consider entries after or on DATE') do |n|
          args[:from_date] = n
        end

        opts.on('-eDATE', '--end=DATE', Date, 'Consider entries before or on DATE') do |n|
          args[:to_date] = n
        end

        opts.on('-lN', '--limit=N', Integer, "Limit to the N most requested resources (defaults to #{limit})") do |n|
          args[:limit] = n
        end

        opts.on('-wWIDTH', '--width=WIDTH', Integer, 'Maximum width of URL and description columns in text reports') do |n|
          args[:width] = n
        end

        opts.on('-cPOLICY', '--crawlers=POLICY', String, 'Decide what to do with crawlers (applies to Apache Logs)') do |n|
          case n
          when 'only'
            args[:only_crawlers] = true
          when 'ignore'
            args[:ignore_crawlers] = true
          end
        end

        opts.on('-ns', '--no-selfpoll', 'Ignore self poll entries (requests from ::1; applies to Apache Logs)') do
          args[:no_selfpoll] = true
        end

        opts.on('-v', '--version', 'Prints version information') do
          puts "log_sense version #{LogSense::VERSION}"
          puts 'Copyright (C) 2021 Shair.Tech'
          puts 'Distributed under the terms of the MIT license'
          exit
        end

        opts.on('-h', '--help', 'Prints this help') do
          puts opts
          puts ''
          puts "This is version #{LogSense::VERSION}"

          puts ''
          puts 'Output formats'
          pathname = File.join(File.dirname(__FILE__), 'templates', '*')
          templates = Dir.glob(pathname).select { |x| !File.basename(x).start_with?(/_|#/) && !File.basename(x).end_with?('~') }
          components = templates.map { |x| File.basename(x).split '.' }.group_by { |x| x[0] }
          components.each do |k, vs|
            puts "#{k} parsing can produce the following outputs:"
            puts '  - sqlite'
            vs.each do |v|
              puts "  - #{v[1]}"
            end
          end

          exit
        end
      end

      opt_parser.parse!(options)

      args[:limit] ||= limit
      args[:input_format] ||= 'apache'
      args[:output_format] ||= 'html'
      args[:ignore_crawlers] ||= false
      args[:only_crawlers] ||= false
      args[:no_selfpoll] ||= false

      args
    end
  end
end
