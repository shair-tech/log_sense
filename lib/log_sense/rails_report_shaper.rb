module LogSense
  class RailsReportShaper < ReportShaper
    def shape(data)
      [
        {
          title: "Daily Distribution",
          header: %w[Day DOW Hits],
          column_alignment: %i[left left right],
          rows: data[:daily_distribution],
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
              data: SERIES_DATA.filter(row => row['Day'] != '').map(row => row['Day']),
              showGrid: true,
            },
            yAxis: {
              type: 'value',
              name: 'Hits',
              showGrid: true,
            },
            series: [
              {
                data: SERIES_DATA.filter(row => row['Day'] != '').map(row => row['Hits']),
                type: 'line',
                color: '#D30001',
                label: {
                  show: true,
                  position: 'top'
                },
              },
            ]
          };",
        },
        {
          title: "Time Distribution",
          header: %w[Hour Hits],
          column_alignment: %i[left right],
          rows: data[:time_distribution],
          echarts_spec: "{
            xAxis: {
              type: 'category',
              data: SERIES_DATA.map(row => row['Hour'])
              /* data: ['00', '01', '02', '03', '04', '05', '06', '07', '08', '09',
                     '10', '11', '12', '13', '14', '15', '16', '17', '18', '19',
                     '20', '21', '22', '23', '24'] */
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
                color: '#D30001',
                label: {
                   show: true,
                   position: 'top'
                },
              }
            ]
          }",
        },
        total_statuses(data),
        daily_statuses(data),
        {
          title: "Rails Performance",
          header: %w[Controller Hits Min Avg Max],
          column_alignment: %i[left right right right right],
          rows: data[:performance],
          col: "small-12 cell",
          echarts_height: "600px",
          echarts_spec: "{
            xAxis: {
            },
            yAxis: {
            },
            tooltip: {
               trigger: 'axis'
            },
            series: [
              {
                data: SERIES_DATA.map(row => [row['Avg'], row['Hits']]),
                type: 'scatter',
                color: '#D30001',
                label: {
                   show: true,
                   position: 'right',
                   formatter: function (params) {
                     var row = SERIES_DATA[params.dataIndex]
                     return row['Controller'] +
                            ': (' + row['Avg'] + ', ' + row['Hits'] + ')';
                   }
                },
              }
            ],
            dataZoom: [
                {
                    type: 'slider', // slider zooming tool on the x-axis
                    xAxisIndex: 0
                },
                {
                    type: 'slider', // slider zooming tool on the y-axis
                    yAxisIndex: 0
                },
                /*
                {
                    type: 'inside', // zooming and panning by dragging and scrolling inside the chart
                    xAxisIndex: 0
                },
                {
                    type: 'inside', // zooming and panning by dragging and scrolling inside the chart
                    yAxisIndex: 0
                }
                */
            ]
          }",
        },
        {
          title: "Controller and Methods by Device",
          header: %w[Controller Method Format iOS Android Mac Windows Linux Other Total],
          column_alignment: %i[left left left right right right right right right right],
          rows: data[:controller_and_methods_by_device],
          col: "small-12 cell",
          echarts_height: "600px",
          echarts_spec: "{
            dataZoom: [{
               type: 'slider', // Use slider type for horizontal zoom
               // ... other dataZoom options
            }],
            series: {
              type: 'treemap',
              roam: 'move',
              label: {
                show: true,
                formatter: function (params) {
                  var parentName = params.treePathInfo.length > 1 ? params.treePathInfo[params.treePathInfo.length - 2].name : '';
                  var nodeName = params.name;
                  var value = params.value;
                  return parentName + '\\n' + nodeName + ':\\n' + value;
                }
              },
              data: #{data[:controller_and_methods_treemap].to_json}
            }
          }"
        },
        {
          title: "Fatal Events",
          header: %w[Date IP URL Description Log ID],
          column_alignment: %i[left left left left left],
          rows: data[:fatal],
          col: "small-12 cell",
          echarts_extra: "var fatal_plot=#{data[:fatal_plot].to_json}",
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
              data: fatal_plot.filter(row => row[0] != '').map(row => row[0]),
              showGrid: true,
              axisLabel: {
                rotate: 45 // Rotate the labels by 90 degrees
              }
            },
            yAxis: {
              type: 'value',
              name: 'Errors',
              showGrid: true,
            },
            series: [
              {
                data: fatal_plot.filter(row => row[0] != '').map(row => row[1]),
                type: 'bar',
                color: '#D30001',
                label: {
                  show: true,
                  position: 'top'
                },
              },
            ]
          };"
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
          header: %w[Log ID Description Count],
          column_alignment: %i[left left left right],
          rows: data[:error],
          col: "small-12 cell"
        },
        {
          title: "Potential Attacks",
          header: %w[Log ID Description Count],
          column_alignment: %i[left left left right],
          rows: data[:possible_attacks],
          col: "small-12 cell"
        },
        {
          title: "Browsers",
          header: %w[Browser Visits],
          column_alignment: %i[left right],
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
                rotate: 45 // Rotate the labels by 90 degrees
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
                color: '#D30001',
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
        },
        {
          title: "Platforms",
          header: %w[Platform Visits],
          column_alignment: %i[left right],
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
                color: '#D30001',
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
          rows: countries_table(data[:countries]),
          echarts_height: "600px",
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
                 color: '#D30001',
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
          k || "-",
          v.map { |x| x[1] }.inject(&:+),
          v.map { |x| x[0] }.uniq.size,
          v.map { |x| x[0] }.join(WORDS_SEPARATOR)
        ]
      }&.sort { |x, y| x[0] <=> y[0] }
    end
  end
end
