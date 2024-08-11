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
      # "https://cdnjs.cloudflare.com/ajax/libs/foundicons/3.0.0/foundation-icons.min.css",
      "https://cdn.jsdelivr.net/npm/foundation-sites@6.8.1/dist/css/foundation.min.css",
      "https://cdn.datatables.net/v/zf/dt-2.0.8/datatables.min.css"
    ].freeze

    CDN_JS = [
      "https://code.jquery.com/jquery-3.7.1.min.js",
      "https://cdn.datatables.net/v/zf/dt-2.0.8/datatables.min.js",
      "https://cdn.jsdelivr.net/npm/foundation-sites@6.8.1/dist/js/foundation.min.js",
      "https://cdn.jsdelivr.net/npm/echarts@5.5.1/dist/echarts.min.js"
    ].freeze

    def self.emit(reports = {}, data = {}, options = {})
      # These are used in templates
      @reports = reports
      @data = data
      @options = options
      @report_title = options[:input_format].capitalize

      @format_specific_theme = "#{@options[:input_format]}_theme.css"
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

    # taken from Ruby on Rails
    JS_ESCAPE_MAP = {
      "\\" => "\\\\",
      "</" => '<\/',
      "\r\n" => '\n',
      "\n" => '\n',
      "\r" => '\n',
      '"' => '\\"',
      "'" => "\\'",
      "`" => "\\`",
      "$" => "\\$"
    }

    # taken from Ruby on Rails
    def self.escape_javascript(javascript)
      javascript = javascript.to_s
      if javascript.empty?
        ""
      else
        javascript.gsub(/(\\|<\/|\r\n|\342\200\250|\342\200\251|[\n\r"']|[`]|[$])/u, JS_ESCAPE_MAP)
      end
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
