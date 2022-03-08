# coding: utf-8
require 'terminal-table'
require 'json'
require 'erb'
require 'ostruct'
module LogSense
  #
  # Emit Data
  #
  module Emitter
    def self.emit data = {}, options = {}
      @input_format = options[:input_format] || 'apache'
      @output_format = options[:output_format] || 'html'

      # for the ERB binding
      @reports = method("#{@input_format}_report_specification".to_sym).call(data)
      @data = data
      @options = options

      # determine the main template to read
      @template = File.join(File.dirname(__FILE__), 'templates', "#{@input_format}.#{@output_format}.erb")
      erb_template = File.read @template
      output = ERB.new(erb_template).result(binding)

      if options[:output_file]
        file = File.open options[:output_file], 'w'
        file.write output
        file.close
      else
        puts output
      end
    end

    def self.render(template, vars = {})
      @template = File.join(File.dirname(__FILE__), 'templates', "_#{template}")
      erb_template = File.read @template
      ERB.new(erb_template).result(OpenStruct.new(vars).instance_eval { binding })
    end

    def self.escape_javascript(string)
      js_escape_map = {
        '<' => '&lt;',
        '</' => '&lt;/',
        '\r\n' => '\\r\\n',
        '\n' => '\\n',
        '\r' => '\\r',
        '\\' => ' \\\\',
        '"' => ' \\"',
        "'" => " \\'",
        '`' => ' \\`',
        '$' => ' \\$'
      }
      js_escape_map.each do |k, v|
        string = string.gsub(k, v)
      end
      string
    end

    def self.slugify(string)
      (string.start_with?(/[0-9]/) ? 'slug-' : '') + string.downcase.gsub(' ', '-')
    end

    def self.process(value)
      klass = value.class
      [Integer, Float].include?(klass) ? value : escape_javascript(value || '')
    end

    # limit width of special columns, that is, URL, Path, and Description
    # - data: array of arrays
    # - heading: array with column names
    # - width width to set
    def self.shorten(data, heading, width)
      # indexes of columns which have to be shortened
      keywords = %w[URL Referers Description Path]
      to_shorten = keywords.map { |x| heading.index x }.compact

      if width.nil? || to_shorten.empty? || data[0].nil?
        data
      else
        table_columns = data[0].size
        data.map { |x|
          (0..table_columns - 1).each.map { |col|
            should_shorten = x[col] && x[col].size > width - 3 && to_shorten.include?(col)
            should_shorten ? "#{x[col][0..(width - 3)]}..." : x[col]
          }
        }
      end
    end

    #
    # Specification of the reports to generate
    # Array of hashes with the following information:
    # - title: report_title
    #   header: header of tabular data
    #   rows: data to show
    #   column_alignment: specification of column alignments (works for txt reports)
    #   vega_spec: specifications for Vega output
    #   datatable_options: specific options for datatable
    def self.apache_report_specification(data = {})
      [
        { title: 'Daily Distribution',
          header: %w[Day DOW Hits Visits Size],
          column_alignment: %i[left left right right right],
          rows: data[:daily_distribution],
          vega_spec: {
            'layer': [
                       {
                         'mark': {
                                   'type': 'line',
                                  'point': {
                                             'filled': false,
                                            'fill': 'white'
                                           }
                                 },
                        'encoding': {
                                      'y': {'field': 'Hits', 'type': 'quantitative'}
                                    }
                       },
                       {
                         'mark': {
                                   'type': 'text',
                                  'color': '#3E5772',
                                  'align': 'middle',
                                  'baseline': 'top',
                                  'dx': -10,
                                  'yOffset': -15
                                 },
                        'encoding': {
                                      'text': {'field': 'Hits', 'type': 'quantitative'},
                                     'y': {'field': 'Hits', 'type': 'quantitative'}
                                    }
                       },

                       {
                         'mark': {
                                   'type': 'line',
                                  'color': '#A52A2A',
                                  'point': {
                                             'color': '#A52A2A',
                                            'filled': false,
                                            'fill': 'white',
                                           }
                                 },
                        'encoding': {
                                      'y': {'field': 'Visits', 'type': 'quantitative'}
                                    }
                       },

                       {
                         'mark': {
                                   'type': 'text',
                                  'color': '#A52A2A',
                                  'align': 'middle',
                                  'baseline': 'top',
                                  'dx': -10,
                                  'yOffset': -15
                                 },
                        'encoding': {
                                      'text': {'field': 'Visits', 'type': 'quantitative'},
                                     'y': {'field': 'Visits', 'type': 'quantitative'}
                                    }
                       },
                       
                     ],
                      'encoding': {
                                    'x': {'field': 'Day', 'type': 'temporal'},
                                  }
          }
          
        },
        { title: 'Time Distribution',
          header: %w[Hour Hits Visits Size],
          column_alignment: %i[left right right right],
          rows: data[:time_distribution],
          vega_spec: {
            'layer': [
                       {
                         'mark': 'bar'
                       },
                       {
                         'mark': {
                                   'type': 'text',
                                  'align': 'middle',
                                  'baseline': 'top',
                                  'dx': -10,
                                  'yOffset': -15
                                 },
                        'encoding': {
                                      'text': {'field': 'Hits', 'type': 'quantitative'},
                                     'y': {'field': 'Hits', 'type': 'quantitative'}
                                    }
                       },
                     ],
                      'encoding': {
                                    'x': {'field': 'Hour', 'type': 'nominal'},
                                   'y': {'field': 'Hits', 'type': 'quantitative'}
                                  }
          }
        },
        {
          title: '20_ and 30_ on HTML pages',
          header: %w[Path Hits Visits Size Status],
          column_alignment: %i[left right right right right],
          rows: data[:most_requested_pages],
          datatable_options: 'columnDefs: [{ width: \'40%\', targets: 0 } ]'
        },
        {
          title: '20_ and 30_ on other resources',
          header: %w[Path Hits Visits Size Status],
          column_alignment: %i[left right right right right],
          rows: data[:most_requested_resources],
          datatable_options: 'columnDefs: [{ width: \'40%\', targets: 0 } ]'
        },
        {
          title: '40_ and 50_x on HTML pages',
          header: %w[Path Hits Visits Status],
          column_alignment: %i[left right right right],
          rows: data[:missed_pages],
          datatable_options: 'columnDefs: [{ width: \'40%\', targets: 0 } ]'
        },
        {
          title: '40_ and 50_ on other resources',
          header: %w[Path Hits Visits Status],
          column_alignment: %i[left right right right],
          rows: data[:missed_resources],
          datatable_options: 'columnDefs: [{ width: \'40%\', targets: 0 } ]'
        },
        {
          title: 'Statuses',
          header: %w[Status Count],
          column_alignment: %i[left right],
          rows: data[:statuses],
          vega_spec: {
            'mark': 'bar',
                      'encoding': {
                                    'x': {'field': 'Status', 'type': 'nominal'},
                                   'y': {'field': 'Count', 'type': 'quantitative'}
                                  }
          }
        },
        {
          title: 'Daily Statuses',
          header: %w[Date S_2xx S_3xx S_4xx],
          column_alignment: %i[left right right right],
          rows: data[:statuses_by_day],
          vega_spec: {
            'transform': [ {'fold': ['S_2xx', 'S_3xx', 'S_4xx' ] }],
                      'mark': 'bar',
                      'encoding': {
                                    'x': {
                                           'field': 'Date',
                                          'type': 'ordinal',
                                          'timeUnit': 'day', 
                                         },
                                   'y': {
                                          'aggregate': 'sum',
                                         'field': 'value',
                                         'type': 'quantitative'
                                        },
                                   'color': {
                                              'field': 'key',
                                             'type': 'nominal',
                                             'scale': {
                                                        'domain': ['S_2xx', 'S_3xx', 'S_4xx'],
                                                       'range': ['#228b22', '#ff8c00', '#a52a2a']
                                                      },
                                            }
                                  }
          }
        },
        { title: 'Browsers',
          header: %w[Browser Hits Visits Size],
          column_alignment: %i[left right right right],
          rows: data[:browsers],
          vega_spec: {
            'layer': [
                       { 'mark': 'bar' },
                       {
                         'mark': {
                                   'type': 'text',
                                  'align': 'middle',
                                  'baseline': 'top',
                                  'dx': -10,
                                  'yOffset': -15
                                 },
                        'encoding': {
                                      'text': {'field': 'Hits', 'type': 'quantitative'},
                                    }
                       },
                     ],
                      'encoding': {
                                    'x': {'field': 'Browser', 'type': 'nominal'},
                                   'y': {'field': 'Hits', 'type': 'quantitative'}
                                  }
          }
        },
        { title: 'Platforms',
          header: %w[Platform Hits Visits Size],
          column_alignment: %i[left right right right],
          rows: data[:platforms],
          vega_spec: {
            'layer': [
                       { 'mark': 'bar' },
                       {
                         'mark': {
                                   'type': 'text',
                                  'align': 'middle',
                                  'baseline': 'top',
                                  'dx': -10,
                                  'yOffset': -15
                                 },
                        'encoding': {
                                      'text': {'field': 'Hits', 'type': 'quantitative'},
                                    }
                       },
                     ],
                      'encoding': {
                                    'x': {'field': 'Platform', 'type': 'nominal'},
                                   'y': {'field': 'Hits', 'type': 'quantitative'}
                                  }
          }
        },
        {
          title: 'IPs',
          header: %w[IPs Hits Visits Size Country],
          column_alignment: %i[left right right right left],
          rows: data[:ips]
        },
        {
          title: 'Countries',
          header: %w[Country Hits Visits IPs],
          column_alignment: %i[left right right left],
          rows: data[:countries]&.map do |k, v|
            [
              k,
              v.map { |x| x[1] }.inject(&:+),
              v.map { |x| x[2] }.inject(&:+),
              v.map { |x| x[0] }.join(' ')
            ]
          end
        },
        {
          title: 'Referers',
          header: %w[Referers Hits Visits Size],
          column_alignment: %i[left right right right],
          rows: data[:referers],
          col: 'small-12 cell'
        },
        {
          title: 'Streaks',
          report: :html,
          header: ['IP', 'Date', 'Total HTML', 'Total Other', 'HTML', 'Other'],
          column_alignment: %i[left left right right left left],
          rows: data[:streaks]&.group_by { |x| [x[0], x[1]] }&.map do |k, v|
            [
              k[0],
              k[1],
              v.map { |x| x[2] }.compact.select { |x| x.match(/\.html?$/) }.size,
              v.map { |x| x[2] }.compact.reject { |x| x.match(/\.html?$/) }.size,
              v.map { |x| x[2] }.compact.select { |x| x.match(/\.html?$/) }.join(' · '),
              v.map { |x| x[2] }.compact.reject { |x| x.match(/\.html?$/) }.join(' · ')
            ]
          end,
          col: 'small-12 cell'
        }
      ]
    end

    def self.rails_report_specification(data = {})
      [
        {
          title: "Daily Distribution",
          header: %w[Day DOW Hits],
          column_alignment: %i[left left right],
          rows: data[:daily_distribution],
          vega_spec: {
            "encoding": {
                          "x": {"field": "Day", "type": "temporal"},
                         "y": {"field": "Hits", "type": "quantitative"}
                        },
                      "layer": [
                                 {
                                   "mark": {
                                             "type": "line",
                                            "point": {
                                                       "filled": false,
                                                      "fill": "white"
                                                     }
                                           }
                                 },
                                 {
                                   "mark": {
                                             "type": "text",
                                            "align": "left",
                                            "baseline": "middle",
                                            "dx": 5
                                           },
                                  "encoding": {
                                                "text": {"field": "Hits", "type": "quantitative"}
                                              }
                                 }
                               ]
          }
        },
        {
          title: "Time Distribution",
          header: %w[Hour Hits],
          column_alignment: %i[left right],
          rows: data[:time_distribution],
          vega_spec: {
            "layer": [
                       {
                         "mark": "bar",
                       },
                       {
                         "mark": {
                                   "type": "text",
                                  "align": "middle",
                                  "baseline": "top",
                                  "dx": -10,
                                  "yOffset": -15
                                 },
                        "encoding": {
                                      "text": {"field": "Hits", "type": "quantitative"}
                                    }
                       }
                     ],
                      "encoding": {
                                    "x": {"field": "Hour", "type": "nominal"},
                                   "y": {"field": "Hits", "type": "quantitative"}
                                  }
          }
        },
        {
          title: "Statuses",
          header: %w[Status Count],
          column_alignment: %i[left right],
          rows: data[:statuses],
          vega_spec: {
            "layer": [
                       {
                         "mark": "bar"
                       },
                       {
                         "mark": {
                                   "type": "text",
                                  "align": "left",
                                  "baseline": "top",
                                  "dx": -10,
                                  "yOffset": -20
                                 },
                        "encoding": {
                                      "text": {"field": "Count", "type": "quantitative"}
                                    }
                       }
                     ],
                      "encoding": {
                                    "x": {"field": "Status", "type": "nominal"},
                                   "y": {"field": "Count", "type": "quantitative"}
                                  }
          }
        },
        {
          title: "Rails Performance",
          header: %w[Controller Hits Min Avg Max],
          column_alignment: %i[left right right right right],
          rows: data[:performance],
          vega_spec: {
            "layer": [
                       {
                         "mark": {
                                   "type": "point",
                                  "name": "data_points"
                                 }
                       },
                       {
                         "mark": {
                                   "name": "label",
                                  "type": "text",
                                  "align": "left",
                                  "baseline": "middle",
                                  "dx": 5,
                                  "yOffset": 0
                                 },
                        "encoding": {
                                      "text": {"field": "Controller"},
                                     "fontSize": {"value": 8}
                                    },
                       },
                     ],
                      "encoding": {
                                    "x": {"field": "Avg", "type": "quantitative"},
                                   "y": {"field": "Hits", "type": "quantitative"}
                                  },
          }
        },
        {
          title: "Fatal Events",
          header: %w[Date IP URL Description Log ID],
          column_alignment: %i[left left left left left],
          rows: data[:fatal],
          col: 'small-12 cell'
        },
        {
          title: 'Internal Server Errors',
          header: %w[Date Status IP URL Description Log ID],
          column_alignment: %i[left left left left left left],
          rows: data[:internal_server_error],
          col: 'small-12 cell'
        },
        {
          title: 'Errors',
          header: %w[Log ID Context Description Count],
          column_alignment: %i[left left left left],
          rows: data[:error],
          col: 'small-12 cell'
        },
        {
          title: 'IPs',
          header: %w[IPs Hits Country],
          column_alignment: %i[left right left],
          rows: data[:ips]
        },
        {
          title: 'Countries',
          header: %w[Country Hits IPs],
          column_alignment: %i[left right left],
          rows: data[:countries]&.map do |k, v|
            [
              k,
              v.map { |x| x[1] }.inject(&:+),
              v.map { |x| x[0] }.join(' · ')
            ]
          end
        },
        {
          title: 'Streaks',
          report: :html,
          header: %w[IP Date Total Resources],
          column_alignment: %i[left left right right left left],
          rows: data[:streaks]&.group_by { |x| [x[0], x[1]] }&.map do |k, v|
            [
              k[0],
              k[1],
              v.size,
              v.map { |x| x[2] }.join(' · ')
            ]
          end,
          col: 'small-12 cell'
        }
      ]
    end
  end
end
