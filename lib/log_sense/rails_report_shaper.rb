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
        time_distribution(data),
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
        browsers(data),
        platforms(data),
        ips(data),
        countries(data),
        ip_per_hour_report_spec(ips_per_hour(data[:ips_per_hour])),
        session_report_spec(ips_detailed(data[:ips_per_day_detailed]))
      ]
    end
  end
end
