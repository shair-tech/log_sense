module LogSense
  class RailsReportShaper < ReportShaper
    def shape(data)
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
                         "mark": { "type": "point",
                                   "name": "data_points"
                                 }
                       },
                       {
                         "mark": { "name": "label",
                                   "type": "text",
                                   "align": "left",
                                   "baseline": "middle",
                                   "dx": 5,
                                   "yOffset": 0
                                 },
                        "encoding": { "text": {"field": "Controller"},
                                      "fontSize": {"value": 8}
                                    },
                       },
                     ],
                      "encoding": { "x": { "field": "Avg",
                                           "type": "quantitative"
                                         },
                                    "y": { "field": "Hits",
                                           "type": "quantitative"
                                         }
                                  },
          }
        },
        {
          title: "Fatal Events",
          header: %w[Date IP URL Description Log ID],
          column_alignment: %i[left left left left left],
          rows: data[:fatal],
          col: "small-12 cell"
        },
        {
          title: "Internal Server Errors",
          header: %w[Date Status IP URL Description Log ID],
          column_alignment: %i[left left left left left left],
          rows: data[:internal_server_error],
          col: "small-12 cell"
        },
        {
          title: "Errors",
          header: %w[Log ID Context Description Count],
          column_alignment: %i[left left left left],
          rows: data[:error],
          col: "small-12 cell"
        },
        {
          title: "IPs",
          header: %w[IPs Hits Country],
          column_alignment: %i[left right left],
          rows: data[:ips]
        },
        {
          title: "Countries",
          header: ["Country", "Hits", "IPs", "IP List"],
          column_alignment: %i[left right left],
          rows: countries_table(data[:countries])
        },
        ip_per_hour_report_spec(ips_per_hour(data[:ips_per_hour])),
        session_report_spec(ips_detailed(data[:ips_per_day_detailed]))
      ]
    end

    private

    # { country => [[ip, visit, country], ...]
    def countries_table(data)
      data&.map { |k, v|
        [
          k,
          v.map { |x| x[1] }.inject(&:+),
          v.map { |x| x[0] }.uniq.size,
          v.map { |x| x[0] }.join(WORDS_SEPARATOR)
        ]
      }&.sort { |x, y| x[0] <=> y[0] }
    end
  end
end
