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
        {
          title: "Statuses",
          header: %w[Status Count],
          column_alignment: %i[left right],
          rows: data[:statuses],
          col: "small-12 cell",
          echarts_spec: "{
            xAxis: {
              type: 'category',
              data: SERIES_DATA.map(row => row['Status'])
              /* data: ['100', '101', '102', '103',
                     '200', '201', '202', '203', '204', '205', '206', '207', '208', '226',
                     '300', '301', '302', '303', '304', '305', '306', '307', '308',
                     '400', '401', '402', '403', '404', '405', '406', '407', '408', '409', '410', '411', '412', '413', '414', '415', '416', '417', '418', '421', '422', '423', '424', '425', '426', '428', '429', '431', '451',
                     '500', '501', '502', '503', '504', '505', '506', '507', '508', '510', '511'] */
            },
            yAxis: {
              type: 'value'
            },
            tooltip: {
               trigger: 'axis'
            },
            series: [
              {
                data: SERIES_DATA.map(row => row['Count']),
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
        {
          title: "Rails Performance",
          header: %w[Controller Hits Min Avg Max],
          column_alignment: %i[left right right right right],
          rows: data[:performance],
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
          title: "Controller and Methods",
          echarts_height: "800px",
          echarts_spec: "{
            series: {
              type: 'treemap',
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
