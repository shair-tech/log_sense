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
          echarts_height: "800px",
          echarts_spec: "{
            xAxis: {
              name: 'Hits',
              type: 'value',
              minInterval: 1,
              axisLabel: {
                formatter: function(val) {
                  return val.toFixed(0);
                }
              }
            },
            yAxis: {
              name: 'Average Time',
              type: 'value',
              axisLabel: {
                formatter: function(val) {
                  return val.toFixed(0) + ' ms';
                }
              }
            },
            tooltip: {
               trigger: 'item',
               formatter: function(params) {
                 var index = params.dataIndex
                 var row = SERIES_DATA[index]
                 var controller = row['Controller']
                 var hits = Number(params.value[0]).toFixed(0).toLocaleString('en')
                 var average = Number(params.value[1]).toFixed(0).toLocaleString('en') + ' ms'
                 return `<b>${controller}</b><br/>Hits: ${hits}<br>Average Time: ${average}`;
               }
            },
            series: [
              {
                data: SERIES_DATA.map(row => [row['Hits'], row['Avg']]),
                type: 'scatter',
                color: '#D30001',
                label: {
                   show: true,
                   position: 'right',
                   formatter: function(params) {
                     var row = SERIES_DATA[params.dataIndex]
                     return row['Controller'];
                     // + 
                     // ':\\n(' + row['Hits'] + ', ' + row['Avg'] + ')';
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
          header: %w[Date IP URL Context Description ID],
          column_alignment: %i[left left left left left left],
          column_width: ["10%", "10%", "20%", "10%", "30%", "20%"],
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
                rotate: 45 // Rotate the labels
              }
            },
            yAxis: {
              type: 'value',
              name: 'Errors',
              showGrid: true,
            },
            series: [
              {
                name: 'Routing Errors',
                data: fatal_plot.filter(row => row[0] != '').map(row => row[2]),
                type: 'bar',
                color: '#D0D0D0',
                label: {
                  show: true,
                  position: 'top'
                },
              },
              {
                name: 'Other Errors',
                data: fatal_plot.filter(row => row[0] != '').map(row => row[3]),
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
          title: "Fatal Events (grouped by type)",
          header: %w[Log ID Context Description Count],
          column_alignment: %i[left left left left right],
          column_width: ["10%", "20%", "10%", "60%", "5%"],
          rows: data[:fatal_grouped],
          col: "small-12 cell"
        },
        browsers(data),
        platforms(data),
        ips(data),
        countries(data),
        ip_per_hour_report_spec(ips_per_hour(data[:ips_per_hour])),
        session_report_spec(ips_detailed(data[:ips_per_day_detailed])),
        {
          title: "Jobs (Completed and Failed)",
          explanation: %(
            This report includes completed and failed jobs, parsing lines
            marked as COMPLETED or ERROR/FAILED.

            This excludes from the table entries marked as RUNNING and then
            completed with "performed".
          ),
          header: %w[Date Duration PID ID Exit_Status Method Arguments Error_Msg Attempts],
          column_alignment: %i[left right left left left left left left right],
          column_width: ["10%", "5%", "5%", "5%", "5%", "15%", "25%", "25%", "5%"],
          rows: data[:jobs],
          col: "small-12 cell",
          echarts_extra: "var fatal_plot=#{data[:job_plot].to_json}",
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
                rotate: 45 // Rotate the labels
              }
            },
            yAxis: {
              type: 'value',
              name: 'Errors',
              showGrid: true,
            },
            series: [
              {
                name: 'Completed',
                data: fatal_plot.filter(row => row[0] != '').map(row => row[1]),
                type: 'bar',
                color: '#D0D0D0',
                label: {
                  show: true,
                  position: 'top'
                },
              },
              {
                name: 'Errors',
                data: fatal_plot.filter(row => row[0] != '').map(row => row[2]),
                type: 'bar',
                color: '#D30001',
                label: {
                  show: true,
                  position: 'top'
                },
              }
            ]
          };"
        },
        {
          title: "Job Errors (grouped)",
          header: %w[Worker Host PID ID Exit_Status Error Method Arguments Attempts],
          column_alignment: %i[left left left left left left left left right],
          column_width: ["5%", "5%", "5%", "5%", "5%", "20%", "25%", "20%", "10%"],
          rows: data[:job_error_grouped],
          col: "small-12 cell"
        }
      ]
    end
  end
end
