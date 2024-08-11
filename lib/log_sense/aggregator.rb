module LogSense
  class Aggregator
    def initialize
      # not meant to be used directly
      raise StandardError
    end

    protected

    def logged_query(query)
      puts query
      @db.execute query
    end

    def aggregate_log_info
      first_day_s = @db.execute "SELECT #{@date_field} from #{@table}
                                 where #{@date_field} not NULL
                                 order by #{@date_field}
                                 limit 1"
      last_day_s  = @db.execute "SELECT #{@date_field} from #{@table}
                                 where #{@date_field} not NULL
                                 order by #{@date_field} desc
                                 limit 1"

      # make first and last day into dates or nil
      @first_day = first_day_s&.first&.first ? Date.parse(first_day_s[0][0]) : nil
      @last_day =  last_day_s&.first&.first ? Date.parse(last_day_s[0][0]) : nil

      @total_days = 0
      @total_days = (@last_day - @first_day).to_i if @first_day && @last_day

      evs = @db.execute "SELECT count(#{@date_field}) from #{@table}"
      @events_in_log = @log_size = evs[0][0]

      evs = @db.execute "SELECT count(#{@date_field}) from #{@table} where #{filter}"
      @events = evs[0][0]

      @source_files = @db.execute "SELECT distinct(source_file) from #{@table}"

      tuv = @db.execute "SELECT count(distinct(unique_visitor)) from #{@table}
                         where #{filter}"
      @total_unique_visits = tuv[0][0]

      @first_day_requested = @options[:from_date]
      @last_day_requested = @options[:to_date]

      @first_day_in_analysis = date_sel @first_day_requested, @first_day, :max
      @last_day_in_analysis = date_sel @last_day_requested, @last_day, :min

      @total_days_in_analysis = 0
      if @first_day_in_analysis && @last_day_in_analysis
        diff = (@last_day_in_analysis - @first_day_in_analysis).to_i
        @total_days_in_analysis = diff
      end
    end

    def aggregate_statuses
      @statuses = @db.execute %(SELECT status, count(status) from #{@table}
                                where #{filter}
                                group by status
                                order by status)

      @by_day_5xx = @db.execute status_query(5)
      @by_day_4xx = @db.execute status_query(4)
      @by_day_3xx = @db.execute status_query(3)
      @by_day_2xx = @db.execute status_query(2)

      all_statuses = @by_day_2xx + @by_day_3xx + @by_day_4xx + @by_day_5xx
      @statuses_by_day = all_statuses.group_by { |x| x[0] }.to_a.map { |x|
        [x[0], x[1].map { |y| y[1] }].flatten
      }
    end

    def aggregate_ips
      if @table == "LogLine"
        extra_cols = ", count(distinct(unique_visitor)), #{human_readable_size}"
      else
        extra_cols = ""
      end

      @ips = @db.execute %(SELECT ip, count(ip) #{extra_cols}
                                  from #{@table}
                                  where #{filter}
                                  group by ip                 
                                  order by count(ip) desc     
                                  limit #{@options[:limit]}).gsub("\n", "")

      @ips_per_hour = @db.execute ip_by_time_query("hour", "%H")
      @ips_per_day = @db.execute ip_by_time_query("day", "%Y-%m-%d")
      @ips_per_week = @db.execute ip_by_time_query("week", "%Y-%W")

      @ips_per_day_detailed = @db.execute %(
          SELECT ip,
                 strftime("%Y-%m-%d", #{@date_field}) as day,
                 #{@url_field}
                 from #{@table}
                 where #{filter} and ip != "" and #{@url_field} != "" and
                       #{@date_field} != ""
                 order by ip, #{@date_field}).gsub("\n", "")
    end

    def instance_vars_to_hash
      data = {}
      instance_variables.each do |variable|
        var_as_symbol = variable.to_s[1..].to_sym
        data[var_as_symbol] = instance_variable_get(variable)
      end
      data
    end
    
    def human_readable_size
      mega = 1024 * 1024
      giga = mega * 1024
      tera = giga * 1024

      %(CASE
         WHEN sum(size) <  1024 THEN sum(size) || ' B' 
         WHEN sum(size) >= 1024 AND sum(size) < (#{mega})
           THEN ROUND((CAST(sum(size) AS REAL) / 1024), 2) || ' KB' 
         WHEN sum(size) >= (#{mega}) AND sum(size) < (#{giga})
           THEN ROUND((CAST(sum(size) AS REAL) / (#{mega})), 2) || ' MB'
         WHEN sum(size) >= (#{giga}) AND sum(size) < (#{tera})
           THEN ROUND((CAST(sum(size) AS REAL) / (#{giga})), 2) || ' GB'
         WHEN sum(size) >= (#{tera})
           THEN ROUND((CAST(sum(size) AS REAL) / (#{tera})), 2) || ' TB' 
      END AS size).gsub("\n", "")
    end

    def human_readable_day
      %(case cast (strftime('%w', #{@date_field}) as integer)
          when 0 then 'Sunday'
          when 1 then 'Monday'
          when 2 then 'Tuesday'
          when 3 then 'Wednesday'
          when 4 then 'Thursday'
          when 5 then 'Friday'
          when 6 then 'Saturday'
          else 'not specified'
        end as dow).gsub("\n", "")
    end

    #
    # generate the where clause corresponding to the command line options to filter data
    #
    def filter
      from = @options[:from_date]
      to = @options[:to_date]
                      
      [
        (from ? "date(#{@date_field}) >= '#{from}'" : nil),
        (to ? "date(#{@date_field}) <= '#{to}'" : nil),
        (@options[:only_crawlers] ? "bot == 1" : nil),
        (@options[:ignore_crawlers] ? "bot == 0" : nil),
        (@options[:no_selfpolls] ? "ip != '::1'" : nil),
        "true"
      ].compact.join " and "
    end

    private

    # given 5 builds the query to get all lines with status 5xx
    def status_query(status)
      %(SELECT date(#{@date_field}), count(#{@date_field}) from #{@table}
               where substr(status, 1,1) == '#{status}' and #{filter}
               group by date(#{@date_field})).gsub("\n", "")
    end

    # given format string, group ip by time formatted with format string
    # (e.g. by hour if format string is "%H")
    # name is used to give the name to the column with formatted time
    def ip_by_time_query(name, format_string)
      %(SELECT ip,
               strftime('#{format_string}', #{@date_field}) as #{name},
               count(#{@url_field}) from #{@table}
               where #{filter} and ip != "" and
               #{@url_field} != "" and
               #{@date_field} != ""
               group by ip, #{name}
               order by ip, #{@date_field}).gsub("\n", "")
    end

    def date_sel(date1, date2, method)
      if date1 && date2
        [date1, date2].send(method)
      elsif date1
        date1
      else
        date2
      end
    end
  end
end
