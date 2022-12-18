module LogSense
  class ApacheReportShaper < ReportShaper
    #
    # Specification of the reports to generate
    # Array of hashes with the following information:
    # - title: report_title
    #   header: header of tabular data
    #   rows: data to show
    #   column_alignment: specification of column alignments (works for txt reports)
    #   vega_spec: specifications for Vega output
    #   datatable_options: specific options for datatable
    def shape(data)
      [
        {
          title: "Daily Distribution",
          header: %w[Day DOW Hits Visits Size],
          column_alignment: %i[left left right right right],
          rows: data[:daily_distribution],
          vega_spec: {
            "layer": [
                       {
                         "mark": {
                                   "type": "line",
                                  "point": {
                                             "filled": false,
                                            "fill": "white"
                                           }
                                 },
                        "encoding": {
                                      "y": {"field": "Hits", "type": "quantitative"}
                                    }
                       },
                       {
                         "mark": {
                                   "type": "text",
                                  "color": "#3E5772",
                                  "align": "middle",
                                  "baseline": "top",
                                  "dx": -10,
                                  "yOffset": -15
                                 },
                        "encoding": {
                                      "text": {"field": "Hits", "type": "quantitative"},
                                     "y": {"field": "Hits", "type": "quantitative"}
                                    }
                       },

                       {
                         "mark": {
                                   "type": "line",
                                  "color": "#A52A2A",
                                  "point": {
                                             "color": "#A52A2A",
                                            "filled": false,
                                            "fill": "white",
                                           }
                                 },
                        "encoding": {
                                      "y": {"field": "Visits", "type": "quantitative"}
                                    }
                       },

                       {
                         "mark": {
                                   "type": "text",
                                  "color": "#A52A2A",
                                  "align": "middle",
                                  "baseline": "top",
                                  "dx": -10,
                                  "yOffset": -15
                                 },
                        "encoding": {
                                      "text": {"field": "Visits", "type": "quantitative"},
                                     "y": {"field": "Visits", "type": "quantitative"}
                                    }
                       },
                       
                     ],
                      "encoding": {
                                    "x": {"field": "Day", "type": "temporal"},
                                  }
          }
        },
        {
          title: "Time Distribution",
          header: %w[Hour Hits Visits Size],
          column_alignment: %i[left right right right],
          rows: data[:time_distribution],
          vega_spec: {
            "layer": [
                       {
                         "mark": "bar"
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
                                      "text": {"field": "Hits", "type": "quantitative"},
                                     "y": {"field": "Hits", "type": "quantitative"}
                                    }
                       },
                     ],
                      "encoding": {
                                    "x": {"field": "Hour", "type": "nominal"},
                                   "y": {"field": "Hits", "type": "quantitative"}
                                  }
          }
        },
        {
          title: "20_ and 30_ on HTML pages",
          header: %w[Path Hits Visits Size Status],
          column_alignment: %i[left right right right right],
          rows: data[:most_requested_pages],
          datatable_options: "columnDefs: [{ width: \"40%\", targets: 0 }, { width: \"15%\", targets: [1, 2, 3, 4] }], dataRender: true"
        },
        {
          title: "20_ and 30_ on other resources",
          header: %w[Path Hits Visits Size Status],
          column_alignment: %i[left right right right right],
          rows: data[:most_requested_resources],
          datatable_options: "columnDefs: [{ width: \"40%\", targets: 0 }, { width: \"15%\", targets: [1, 2, 3, 4] }], dataRender: true"
        },
        {
          title: "40_ and 50_x on HTML pages",
          header: %w[Path Hits Visits Status],
          column_alignment: %i[left right right right],
          rows: data[:missed_pages],
          datatable_options: "columnDefs: [{ width: \"40%\", targets: 0 }, { width: \"20%\", targets: [1, 2, 3] }], dataRender: true"
        },
        {
          title: "40_ and 50_ on other resources",
          header: %w[Path Hits Visits Status],
          column_alignment: %i[left right right right],
          rows: data[:missed_resources],
          datatable_options: "columnDefs: [{ width: \"40%\", targets: 0 }, { width: \"20%\", targets: [1, 2, 3] }], dataRender: true"
        },
        {
          title: "40_ and 50_x on HTML pages by IP",
          header: %w[IP Hits Paths],
          column_alignment: %i[left right left],
          # Value is something along the line of:
          # [["66.249.79.93", "/adolfo/notes/calendar/2014/11/16.html", "404"],
          #  ["66.249.79.93", "/adolfo/website-specification/generate-xml-sitemap.org.html", "404"]]
          rows: data[:missed_pages_by_ip]&.group_by { |x| x[0] }&.map { |k, v|
            [
              k,
              v.size,
              v.map { |x| x[1] }.join(WORDS_SEPARATOR)
            ]
          }&.sort { |x, y| y[1] <=> x[1] }
        },
        {
          title: "40_ and 50_ on other resources by IP",
          header: %w[IP Hits Paths],
          column_alignment: %i[left right left],
          # Value is something along the line of:
          # [["66.249.79.93", "/adolfo/notes/calendar/2014/11/16.html", "404"],
          #  ["66.249.79.93", "/adolfo/website-specification/generate-xml-sitemap.org.html", "404"]]
          rows: data[:missed_resources_by_ip]&.group_by { |x| x[0] }&.map { |k, v|
            [
              k,
              v.size,
              v.map { |x| x[1] }.join(WORDS_SEPARATOR)
            ]
          }&.sort { |x, y| y[1] <=> x[1] }
        },
        {
          title: "Statuses",
          header: %w[Status Count],
          column_alignment: %i[left right],
          rows: data[:statuses],
          vega_spec: {
            "mark": "bar",
                      "encoding": {
                                    "x": {"field": "Status", "type": "nominal"},
                                   "y": {"field": "Count", "type": "quantitative"}
                                  }
          }
        },
        {
          title: "Daily Statuses",
          header: %w[Date S_2xx S_3xx S_4xx S_5xx],
          column_alignment: %i[left right right right right],
          rows: data[:statuses_by_day],
          vega_spec: {
            "transform": [ {"fold": ["S_2xx", "S_3xx", "S_4xx", "S_5xx" ] }],
                      "mark": "bar",
                      "encoding": {
                                    "x": { 
                                           "field": "Date",
                                           "type": "ordinal",
                                           "timeUnit": "day", 
                                         },
                                   "y": {
                                          "aggregate": "sum",
                                         "field": "value",
                                         "type": "quantitative"
                                        },
                                   "color": {
                                              "field": "key",
                                             "type": "nominal",
                                             "scale": {
                                                        "domain": ["S_2xx", "S_3xx", "S_4xx"],
                                                       "range": ["#228b22", "#ff8c00", "#a52a2a"]
                                                      },
                                            }
                                  }
          }
        },
        {
          title: "Browsers",
          header: %w[Browser Hits Visits Size],
          column_alignment: %i[left right right right],
          rows: data[:browsers],
          vega_spec: {
            "layer": [
                       { "mark": "bar" },
                       {
                         "mark": {
                                   "type": "text",
                                  "align": "middle",
                                  "baseline": "top",
                                  "dx": -10,
                                  "yOffset": -15
                                 },
                        "encoding": {
                                      "text": {"field": "Hits", "type": "quantitative"},
                                    }
                       },
                     ],
                      "encoding": {
                                    "x": {"field": "Browser", "type": "nominal"},
                                   "y": {"field": "Hits", "type": "quantitative"}
                                  }
          }
        },
        {
          title: "Platforms",
          header: %w[Platform Hits Visits Size],
          column_alignment: %i[left right right right],
          rows: data[:platforms],
          vega_spec: {
            "layer": [
                       { "mark": "bar" },
                       {
                         "mark": {
                                   "type": "text",
                                  "align": "middle",
                                  "baseline": "top",
                                  "dx": -10,
                                  "yOffset": -15
                                 },
                        "encoding": {
                                      "text": {"field": "Hits", "type": "quantitative"},
                                    }
                       },
                     ],
                      "encoding": {
                                    "x": {"field": "Platform", "type": "nominal"},
                                   "y": {"field": "Hits", "type": "quantitative"}
                                  }
          }
        },
        {
          title: "IPs",
          header: %w[IP Hits Visits Size Country],
          column_alignment: %i[left right right right left],
          rows: data[:ips]
        },
        {
          title: "Countries",
          header: ["Country", "Hits", "Visits", "IPs", "IP List"],
          column_alignment: %i[left right right right left],
          rows: data[:countries]&.map { |k, v|
            [
              k,
              v.map { |x| x[1] }.inject(&:+),
              v.map { |x| x[2] }.inject(&:+),
              v.map { |x| x[0] }.uniq.size,
              v.map { |x| x[0] }.join(WORDS_SEPARATOR)
            ]
          }&.sort { |x, y| y[3] <=> x[3] }
        },
        ip_per_hour_report_spec(ips_per_hour(data[:ips_per_hour])),
        {
          title: "Combined Platform Data",
          header: %w[Browser OS IP Hits Size],
          column_alignment: %i[left left left right right],
          col: "small-12 cell",
          rows: data[:combined_platforms],
        },
        {
          title: "Referers",
          header: %w[Referers Hits Visits Size],
          column_alignment: %i[left right right right],
          datatable_options: "columnDefs: [{ width: \"50%\", targets: 0 } ], dataRender: true",
          rows: data[:referers],
          col: "small-12 cell"
        },
        session_report_spec(ips_detailed(data[:ips_per_day_detailed]))
      ]
    end
  end
end
