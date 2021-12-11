module LogSense
  module RailsDataCruncher

    #
    # take a sqlite3 database and analyze data
    #
    # @ variables are automatically put in the returned data
    #

    def self.crunch db, options = { limit: 30 }
      first_day_s = db.execute "SELECT started_at from Event where started_at not NULL order by started_at limit 1"
      # we could use ended_at to cover the full activity period, but I prefer started_at
      # with the meaning that the monitor event initiation
      last_day_s  = db.execute "SELECT started_at from Event order by started_at desc limit 1"

      # make first and last day into dates or nil
      # TODO: bug possible value here: [[nil]], which is not empty
      @first_day = ! first_day_s[0][0] ? nil : Date.parse(first_day_s[0][0])
      @last_day = ! last_day_s[0][0] ? nil : Date.parse(last_day_s[0][0])

      @total_days = 0
      if @first_day and @last_day
        @total_days = (@last_day - @first_day).to_i
      end

      @events = db.execute "SELECT count(started_at) from Event"

      @first_day_requested = options[:from_date]
      @last_day_requested = options[:to_date]

      @first_day_in_analysis = date_intersect options[:from_date], @first_day, :max
      @last_day_in_analysis = date_intersect options[:to_date], @last_day, :min

      @total_days_in_analysis = 0
      if @first_day_in_analysis and @last_day_in_analysis
        @total_days_in_analysis = (@last_day_in_analysis - @first_day_in_analysis).to_i
      end

      #
      # generate the where clause corresponding to the command line options to filter data
      #
      filter = [
        (options[:from_date] ? "date(started_at) >= '#{options[:from_date]}'" : nil),
        (options[:to_date] ? "date(started_at) <= '#{options[:to_date]}'" : nil),
        "true"
      ].compact.join " and "

      mega = 1024 * 1024
      giga = mega * 1024
      tera = giga * 1024
      
      # in alternative to sum(size)
      human_readable_size = <<-EOS
      CASE 
      WHEN sum(size) <  1024 THEN sum(size) || ' B' 
      WHEN sum(size) >= 1024 AND sum(size) < (#{mega}) THEN ROUND((CAST(sum(size) AS REAL) / 1024), 2) || ' KB' 
      WHEN sum(size) >= (#{mega})  AND sum(size) < (#{giga}) THEN ROUND((CAST(sum(size) AS REAL) / (#{mega})), 2) || ' MB' 
      WHEN sum(size) >= (#{giga}) AND sum(size) < (#{tera}) THEN ROUND((CAST(sum(size) AS REAL) / (#{giga})), 2) || ' GB' 
      WHEN sum(size) >= (#{tera}) THEN ROUND((CAST(sum(size) AS REAL) / (#{tera})), 2) || ' TB' 
      END AS size
      EOS

      human_readable_day = <<-EOS
        case cast (strftime('%w', started_at) as integer)
          when 0 then 'Sunday'
          when 1 then 'Monday'
          when 2 then 'Tuesday'
          when 3 then 'Wednesday'
          when 4 then 'Thursday'
          when 5 then 'Friday'
          else 'Saturday'
        end as dow
      EOS

      @total_events = db.execute "SELECT count(started_at) from Event where #{filter}"

      @daily_distribution = db.execute "SELECT date(started_at), #{human_readable_day}, count(started_at) from Event where #{filter} group by date(started_at)"
      @time_distribution = db.execute "SELECT strftime('%H', started_at), count(started_at) from Event where #{filter} group by strftime('%H', started_at)"

      @statuses = db.execute "SELECT status, count(status) from Event where #{filter} group by status order by status"

      @by_day_4xx = db.execute "SELECT date(started_at), count(started_at) from Event where substr(status, 1,1) == '4' and #{filter} group by date(started_at)"
      @by_day_3xx = db.execute "SELECT date(started_at), count(started_at) from Event where substr(status, 1,1) == '3' and #{filter} group by date(started_at)"
      @by_day_2xx = db.execute "SELECT date(started_at), count(started_at) from Event where substr(status, 1,1) == '2' and #{filter} group by date(started_at)"

      @statuses_by_day = (@by_day_2xx + @by_day_3xx + @by_day_4xx).group_by { |x| x[0] }.to_a.map { |x|
        [x[0], x[1].map { |y| y[1] }].flatten
      }

      @ips = db.execute "SELECT ip, count(ip) from Event where #{filter} group by ip order by count(ip) desc limit #{options[:limit]}"

      @performance = db.execute "SELECT distinct(controller), count(controller), printf(\"%.2f\", min(duration_total_ms)), printf(\"%.2f\", avg(duration_total_ms)), printf(\"%.2f\", max(duration_total_ms)) from Event group by controller order by controller"

      data = {}
      self.instance_variables.each do |variable|
        var_as_symbol = variable.to_s[1..-1].to_sym
        data[var_as_symbol] = eval(variable.to_s)
      end
      data
    end

    private

    def self.date_intersect date1, date2, method
      if date1 and date2
        [date1, date2].send(method)
      elsif date1
        date1
      else
        date2
      end
    end


  end
end

