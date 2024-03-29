# coding: utf-8
require "terminal-table"
require "json"
require "erb"
require "ostruct"

module LogSense
  #
  # Emit Data
  #
  class Emitter
    CDN_CSS = [
      "https://cdnjs.cloudflare.com/ajax/libs/foundicons/3.0.0/foundation-icons.min.css",
      "https://cdn.jsdelivr.net/npm/foundation-sites@6.7.5/dist/css/foundation.min.css",
      "https://cdn.datatables.net/v/zf/dt-1.11.3/datatables.min.css"
    ].freeze

    CDN_JS = [
      "https://code.jquery.com/jquery-3.6.2.min.js",
      "https://cdn.datatables.net/v/zf/dt-1.13.1/datatables.min.js",
      "https://cdn.jsdelivr.net/npm/foundation-sites@6.7.5/dist/js/foundation.min.js",
      "https://cdn.jsdelivr.net/npm/vega@5.22.1",
      "https://cdn.jsdelivr.net/npm/vega-lite@5.6.0",
      "https://cdn.jsdelivr.net/npm/vega-embed@6.21.0"
    ].freeze

    def self.emit(reports = {}, data = {}, options = {})
      # These are used in templates
      @reports = reports
      @data = data
      @options = options
      @report_title = options[:input_format].capitalize
      @format_specific_css = "#{@options[:input_format]}.css.erb"

      # Chooses template and destination
      output_format = @options[:output_format]
      output_file = @options[:output_file]

      # read template and compile
      template = File.join(File.dirname(__FILE__),
                           "templates",
                           "report_#{output_format}.erb")
      erb_template = File.read template
      output = ERB.new(erb_template, trim_mode: "-").result(binding)

      # output
      if output_file
        file = File.open output_file, "w"
        file.write output
        file.close
      else
        puts output
      end
    end

    #
    # These are used in templates
    #

    def self.render(template, vars = {})
      @template = File.join(File.dirname(__FILE__), "templates", "_#{template}")
      if File.exist? @template
        erb_template = File.read @template
        ERB.new(erb_template, trim_mode: "-")
          .result(OpenStruct.new(vars).instance_eval { binding })
      end
    end

    def self.escape_javascript(string)
      js_escape_map = {
        #"&" => "&amp;",
        #"%" => "&#37;",
        "<" => "&lt;",
        "\\" => "&bsol;",
        '"' => ' \\"',
        "'" => " \\'",
        "`" => " \\`",
        "$" => " \\$"
      }
      js_escape_map.each do |match, replace|
        string = string.gsub(match, replace)
      end
      string
    end

    def self.slugify(string)
      (string.start_with?(/[0-9]/) ? "slug-" : "") + string.downcase.gsub(" ", "-")
    end

    def self.process(value)
      klass = value.class
      [Integer, Float].include?(klass) ? value : escape_javascript(value || "")
    end

    # limit width of special columns, that is, those in keywords
    # - data: array of arrays
    # - heading: array with column names
    # - width width to set
    def self.shorten(data, heading, width, inner_rows)
      # columns which need to be shortened
      keywords = ["URL", "Referers", "Description", "Path", "Paths", "IP List"]
      # indexes of columns which have to be shortened (= index in array)
      to_shorten = keywords.map { |idx| heading.index idx }.compact

      if data[0].nil? || width.nil? || to_shorten.empty?
        data
      else
        # how many columns do we have?
        table_columns = data[0].size
        data.map do |x|
          # we iterate over all columns, because we want to return a table
          # with the same structure of the input table
          (0..table_columns - 1).each.map do |col|
            # split cell into (internal) rows, if necessary
            content_in_rows = x[col].to_s.split WORDS_SEPARATOR
            # remove excess rows, shorten each string and return what's left
            # single cells are returned as they are
            rows_limit = inner_rows || content_in_rows.size
            content = content_in_rows[0..(rows_limit - 1)].map { |x|
              if x.size > width && to_shorten.include?(col)
                "#{x[0..(width - 3)]}..."
              else
                x
              end
            }.join("\n")
          end
        end
      end
    end
  end
end
