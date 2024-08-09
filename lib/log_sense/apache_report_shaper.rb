module LogSense
  class ApacheReportShaper < ReportShaper
    #
    # Specification of the reports to generate
    # Array of hashes with the following information:
    # - title: report_title
    #   header: header of tabular data
    #   rows: data to show
    #   column_alignment: specification of column alignments (works for txt reports)
    #   echarts_spec: specifications for eCharts output
    #   vega_spec: specifications for Vega output
    #   datatable_options: specific options for datatable
    def shape(data)
      [
        {
          title: "Daily Distribution",
          header: %w[Day DOW Hits Visits Size],
          column_alignment: %i[left left right right right],
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
            legend: {
                data: ['Hits', 'Visits']
            },
            xAxis: {
              type: 'category',
              data: SERIES_DATA.filter(row => row['Day'] != '').map(row => row['Day']),
              showGrid: true,
            },
            yAxis: {
              type: 'value',
              name: 'Hits & Visits',
              showGrid: true,
            },
            series: [
              {
                name: 'Hits',
                data: SERIES_DATA.filter(row => row['Day'] != '').map(row => row['Hits']),
                type: 'line',
                color: '#4C78A8',
                label: {
                  show: true,
                  position: 'top'
                },
              },
              {
                name: 'Visits',
                data: SERIES_DATA.filter(row => row['Day'] != '').map(row => row['Visits']),
                type: 'line',
                color: '#D30001',
                label: {
                  show: true,
                  position: 'top'
                },
              },
            ]
          }
        ",
        },
        {
          title: "Time Distribution",
          header: %w[Hour Hits Visits Size],
          column_alignment: %i[left right right right],
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
                color: '#4C78A8',
                label: {
                   show: true,
                   position: 'top'
                },
              }
            ]
          }",
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
          header: %w[Path Hits Visits Size Status],
          column_alignment: %i[left right right right right],
          rows: data[:missed_pages],
          datatable_options: "columnDefs: [{ width: \"40%\", targets: 0 }, { width: \"20%\", targets: [1, 2, 3] }], dataRender: true"
        },
        {
          title: "40_ and 50_ on other resources",
          header: %w[Path Hits Visits Size Status],
          column_alignment: %i[left right right right right],
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
        total_statuses(data),
        daily_statuses(data),
        {
          title: "Browsers",
          header: %w[Browser Hits Visits Size],
          column_alignment: %i[left right right right],
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
              name: 'Browser Hits',
              showGrid: true,
            },
            series: [
              {
                name: 'Hits',
                data: SERIES_DATA.sort(order_by_name).map(row => row['Hits']),
                type: 'bar',
                color: '#4C78A8',
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
          header: %w[Platform Hits Visits Size],
          column_alignment: %i[left right right right],
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
              name: 'Platform Hits',
              showGrid: true,
            },
            series: [
              {
                name: 'Hits',
                data: SERIES_DATA.sort(order_by_platform).map(row => row['Hits']),
                type: 'bar',
                color: '#4C78A8',
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
          }&.sort { |x, y| y[3] <=> x[3] },
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
                 color: '#4C78A8',
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
