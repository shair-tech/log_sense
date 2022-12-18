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
  end
end
