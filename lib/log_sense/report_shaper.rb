module LogSense
  class ReportShaper
    SESSION_URL_LIMIT = 300
    WORDS_SEPARATOR = ' · '

    # return { [ip,day] => { [ hits, list of urls ] } }
    def ips_detailed(ips_per_day)
      hash = pivot(ips_per_day, 0, 1, lambda { |array| array.map { |x| x[2] } })
      array = []
      hash.keys.map do |ip|
        array += hash[ip].keys.map do |date|
          [
            ip,
            hash[ip].keys.size,
            date,
            hash[ip][date].size,
            hash[ip][date].uniq.size,
            if hash[ip][date].uniq.size < SESSION_URL_LIMIT
              hash[ip][date].uniq.join(WORDS_SEPARATOR)
            else
              "[too many]"
            end
          ]
        end
      end
      array
    end

    def ips_per_hour(ips_per_hour)
      hash = pivot(ips_per_hour, 0, 1)
      hash.keys.map do |ip|
        [
          ip,
          (0..23).map { |hour| hash[ip][hour.to_s]&.to_i }
        ].flatten
      end
    end

    # Shape an array of arrays into a hash of hashes (row, cols)
    # Params:
    # +input_data+:: array of array
    # +row_key+::    index of the inner array or lambda, used to group data
    #                by rows
    # +col_key+::    index of the inner array or lambda, will be used
    #                to group cols
    # +cell+::       lambda to get the value of the cells to put in the hashes.
    #                Takes and array as input (that is, an array of all the
    #                elements resulting from grouping)
    #
    # Example
    #
    #  input_array: [[IP, HOUR, VISITS], [...]],
    #  row_key: 0
    #  col_key: 1
    #  cell: lambda { |x| x[2] }
    #
    # Will output:
    #
    #  { IP => { HOUR => VISITS, HOUR => VISITS }, ... }
    #
    def pivot(input_data,
              row_key,
              col_key,
              cell_maker = lambda { |x| x[0].last })
      # here we build:
      # "95.108.213.66"=>{12=>1, 18=>2, 19=>1, 20=>1, 5=>3, 6=>2, 7=>2, 3=>1},
      #
      # first transform: IP => [ HOUR => [[IP,HOUR,T], [IP,HOUR,T]] ]
      # second transform: [IP,HOUR,T] -> T
      input_data.group_by { |entry|
        if row_key.class == Integer
          entry[row_key]
        else
          row_key.call(entry)
        end
      }.transform_values { |rows|
        rows.group_by { |cols|
          if col_key.class == Integer
            cols[col_key]
          else
            col_key.call(cols)
          end
        }.transform_values { |array|
          cell_maker.call(array)
        }
      }
    end

    def performance_over_time(data, colors: ["#d30001", "#888888"], col: "small-12 cell")
      {
        title: "Performance over Time",
        header: %w[Date Count Min Avg Max],
        column_alignment: %i[center right right right right],
        rows: data[:performance_over_time],
        col: col,
        echarts_spec: "{
            xAxis: {
              type: 'category',
              data: SERIES_DATA.map(row => row['Date'])
            },
            yAxis: [
              {
                type: 'value',
                name: 'Average'
              },
              {
                type: 'value',
                name: 'Max'
              }
            ],
            tooltip: {
               trigger: 'axis'
            },
            series: [
              {
                data: SERIES_DATA.map(row => row['Avg']),
                type: 'line',
                color: '#{colors[0]}',
                label: {
                   show: true,
                   position: 'top'
                },
              },
              {
                data: SERIES_DATA.map(row => row['Max']),
                type: 'line',
                color: '#{colors[1]}',
                yAxisIndex: 1,
                label: {
                   show: true,
                   position: 'top'
                },
              },
            ]
          }",
      }
    end

    def queries(data, colors: [], col: "small-12 cell")
      {
        title: "Number of queries",
        header: %w[Events Queries Cached Perc_Cached],
        column_alignment: %i[center center center center],
        rows: data[:queries],
        col: col,
      }      
    end

    def queries_by_controller(data, colors: [], col: "small-12 cell")
      {
        title: "Queries by Controller",
        header: ["Controller",
                 "Events",
                 "Min queries", "Max queries", "Avg Queries",
                 "Total queries", "Cached queries", "Perc",
                 "Total GC"],
        column_alignment: %i[left right right right right right right right],
        rows: data[:queries_by_controller],
        col: col,
      }      
    end

    #
    # Reports shared between rails and apache/nginx
    #

    def time_distribution(data, header: %w[Hour Hits], column_alignment: %i[left right], color: "#d30001")
      {
        title: "Time Distribution",
        header:,
        column_alignment:,
        rows: data[:time_distribution],
        echarts_spec: "{
            xAxis: {
              type: 'category',
              data: SERIES_DATA.map(row => row['Hour'])
            },
            yAxis: {
              type: 'value'
            },
            tooltip: {
               trigger: 'axis'
            },
            series: [
              {
                data: SERIES_DATA.map(row => row['Hits']),
                type: 'bar',
                color: '#{color}',
                label: {
                   show: true,
                   position: 'top'
                },
              }
            ]
          }",
      }
    end

    def browsers(data, header: %w[Browser Visits], column_alignment: %i[left right], color: "#D30001")
      {
        title: "Browsers",
        header:,
        column_alignment:,
        rows: data[:browsers],
        echarts_spec: "{
            toolbox: {
               feature: {
                 saveAsImage: {},
               }
            },
            tooltip: {
               trigger: 'axis'
            },
            xAxis: {
              type: 'category',
              data: SERIES_DATA.sort(order_by_name).map(row => row['Browser']),
              showGrid: true,
              axisLabel: {
                rotate: 45 // Rotate the labels (degrees)
              }
            },
            yAxis: {
              type: 'value',
              name: 'Browser Visits',
              showGrid: true,
            },
            series: [
              {
                name: 'Hits',
                data: SERIES_DATA.sort(order_by_name).map(row => row['Visits']),
                type: 'bar',
                color: '#{color}',
                label: {
                  show: true,
                  position: 'top'
                },
              },
            ]
          }
          function order_by_name(a, b) {
            return a['Browser'] < b['Browser'] ? -1 : 1
          }
          ",
      }
    end

    def platforms(data, header: %w[Platform Visits], column_alignment: %i[left right], color: "#d30001")
      {
        title: "Platforms",
        header:,
        column_alignment:,
        rows: data[:platforms],
        echarts_spec: "{
            toolbox: {
               feature: {
                 saveAsImage: {},
               }
            },
            tooltip: {
               trigger: 'axis'
            },
            xAxis: {
              type: 'category',
              data: SERIES_DATA.sort(order_by_platform).map(row => row['Platform']),
              showGrid: true,
              axisLabel: {
                rotate: 45 // Rotate the labels by 90 degrees
              }
            },
            yAxis: {
              type: 'value',
              name: 'Platform Visits',
              showGrid: true,
            },
            series: [
              {
                name: 'Visits',
                data: SERIES_DATA.sort(order_by_platform).map(row => row['Visits']),
                type: 'bar',
                color: '#{color}',
                label: {
                  show: true,
                  position: 'top'
                },
              },
            ]
          }
          function order_by_platform(a, b) {
            return a['Platform'] < b['Platform'] ? -1 : 1
          }",
      }
    end

    def ips(data, header: %w[IPs Hits Country], column_alignment: %i[left right left], palette: :rails)
      {
        title: "IPs",
        header:,
        column_alignment:,
        # must be like raw_html_height below
        raw_html_height: "500px",
        raw_html: "
            <style>
            #{countries_css_styles(data[:countries], palette:)}
            </style>
            #{File.read(File.join(File.dirname(__FILE__), "templates", "world.svg"))}
          ",
        rows: data[:ips]
      }
    end

    def countries(data, header: ["Country", "Hits", "IPs", "IP List"], column_alignment: %i[left right left left], color: "#D30001")
      {
        title: "Countries",
        header:,
        column_alignment: ,
        rows: countries_table(data[:countries]),
        # must be like raw_html_height above
        echarts_height: "500px",
        echarts_spec: "{
            tooltip: {
                trigger: 'axis',
                axisPointer: {
                  type: 'shadow'
                }
            },
            xAxis: {
              type: 'value',
              boundaryGap: [0, 0.01]
            },
            yAxis: {
              type: 'category',
              data: SERIES_DATA.sort(order_by_hits).map(row => row['Country'] ),
            },
            series: [
              {
                 type: 'bar',
                 data: SERIES_DATA.sort(order_by_hits).map(row => row['Hits'] ),
                 color: '#{color}',
                 label: {
                    show: true,
                    position: 'right'
                 },
              },
            ]
          };

          function order_by_hits(a, b) {
            return Number(a['Hits']) < Number(b['Hits']) ? -1 : 1
          }
          "
      }
    end

    def session_report_spec(data)
      {
        title: "Sessions",
        report: :html,
        header: ["IP", "Days", "Date", "Visits", "Distinct URL", "URL List"],
        column_alignment: %i[left left right right right left],
        rows: data,
        col: "small-12 cell"
      }
    end

    def ip_per_hour_report_spec(data)
      {
        title: "IP per hour",
        header: ["IP"] + (0..23).map { |hour| hour.to_s },
        column_alignment: %i[left] + (%i[right] * 24),
        column_width: ["10%"] + (["3.75%"] * 24),
        rows: data,
        col: "small-12 cell"
      }
    end

    def total_statuses(data)
      {
        title: "Statuses",
        header: %w[Status Count],
        column_alignment: %i[left right],
        rows: data[:statuses],
        echarts_spec: "{
            xAxis: {
              type: 'category',
              data: SERIES_DATA.map(row => row['Status'])
            },
            yAxis: {
              type: 'value'
            },
            tooltip: {
               trigger: 'axis'
            },
            series: [
              {
                data: SERIES_DATA.map(row => {
                  var color;
                  var first_char = row['Status'].slice(0, 1)
                  switch (first_char) {
                    case '2':
                      color = '#218521';
                      break;
                    case '3':
                      color = '#FF8C00';
                      break;
                    case '4':
                      color = '#A52A2A';
                      break
                    case '5':
                      color = '#000000';
                      break;
                    default:
                      color = '#4C78A8';
                  }
                  return {
                    value: row['Count'],
                    itemStyle: { color: color }
                  }
                }),
                type: 'bar',
                label: {
                   show: true,
                   position: 'top'
                },
              }
            ]
          }",
      }
    end

    def daily_statuses(data)
      {
        title: "Statuses by Day",
        header: %w[Date S_2xx S_3xx S_4xx S_5xx],
        column_alignment: %i[left right right right right],
        rows: data[:statuses_by_day],
        echarts_spec: "{
            xAxis: {
              type: 'category',
              data: SERIES_DATA.map(row => row['Date'])
            },
            yAxis: {
              type: 'value'
            },
            tooltip: {
               trigger: 'axis'
            },
            series: [
              {
                data: SERIES_DATA.map(row => row['S_2xx']),
                type: 'bar',
                color: '#218521',
                stack: 'total',
                label: {
                   show: true,
                   position: 'right'
                },
              },
              {
                data: SERIES_DATA.map(row => row['S_3xx']),
                type: 'bar',
                color: '#FF8C00',
                stack: 'total',
                label: {
                   show: true,
                   position: 'right'
                },
              },
              {
                data: SERIES_DATA.map(row => row['S_4xx']),
                type: 'bar',
                color: '#A52A2A',
                stack: 'total',
                label: {
                   show: true,
                   position: 'right'
                },
              },
              {
                data: SERIES_DATA.map(row => row['S_5xx']),
                type: 'bar',
                color: '#000000',
                stack: 'total',
                label: {
                   show: true,
                   position: 'right'
                },
              },
            ]
          }",
      }
    end

    private

    def countries_css_styles(country_data, palette: :rails)
      country_and_hits = country_data&.map { |k, v|
        [k, v.map { |x| x[1] }.inject(&:+)]
      }
      max = country_and_hits.map { |x| x[1] }.max

      country_and_hits.map do |element|
        underscored = (element[0] || "").gsub(" ", "_").gsub(/[()]/, "")
        bin = bin(element[1], max:)
        <<-EOS
         /* bin: #{bin} */
         .#{underscored}, ##{underscored}, path[name="#{underscored}"] {
           fill: #{fill_color(bin, palette:)}
         }
        EOS
      end.join("\n")
    end

    # return the fill colors for the map
    # https://www.learnui.design/tools/data-color-picker.html#single
    def fill_color(bin, palette: :rails)
      colors = if palette == :rails
                 ["#fff2e2", "#f9ddbe", "#f4c79b", "#efb07b", "#ea985e",
                  "#e57f43", "#e0632a", "#da4314", "#d30001"]
               else
                 ["#e3ffff", "#cbedf1", "#b3dce4", "#9dcad7", "#87b8cc",
                  "#74a6c0", "#6394b5", "#5482a9", "#48709c"]
               end

      colors[bin] || colors.last
    end

    # make number_of_bins bins between 0 and max and return in which bin
    # number belongs to
    def bin(number, number_of_bins: 9, max: 100)
      ((number / max.to_f) * number_of_bins).to_i
    end

    # { country => [[ip, visit, country], ...]
    def countries_table(data, limit: 15)
      by_country = data&.map { |k, v|
        [
          k || "-",
          v.map { |x| x[1] }.inject(&:+),
          v.map { |x| x[0] }.uniq.size,
          v.map { |x| x[0] }.join(WORDS_SEPARATOR)
        ]
      }&.sort { |x, y| x[0] <=> y[0] }

      # return the first limit countries
      (by_country || [])[0..limit - 1]
    end
  end
end
