module LogSense
  class ReportShaper
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
            hash[ip][date].uniq.size < 100 ? hash[ip][date].uniq.join(WORDS_SEPARATOR) : "[too many]"
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

    def session_report_spec(data)
      {
        title: "Sessions",
        report: :html,
        header: ["IP", "Days", "Date", "Visits", "Distinct URL", "URL List"],
        column_alignment: %i[left left right right right right],
        rows: data,
        col: "small-12 cell"
      }
    end

    def ip_per_hour_report_spec(data)
      {
        title: "IP per hour",
        header: ["IP"] + (0..23).map { |hour| hour.to_s },
        column_alignment: [:left] + [:right] * 24,
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
        title: "Daily Statuses",
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
  end
end
