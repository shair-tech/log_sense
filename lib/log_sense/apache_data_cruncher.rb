module LogSense
  module ApacheDataCruncher
    #
    # take a sqlite3 database and analyze data
    #
    # @ variables are automatically put in the returned data
    #

    def self.crunch db, options = { limit: 900 }
      first_day_s = db.execute "SELECT datetime from LogLine order by datetime limit 1"
      last_day_s  = db.execute "SELECT datetime from LogLine order by datetime desc limit 1"

      # make first and last day into dates or nil
      @first_day = first_day_s&.first&.first ? Date.parse(first_day_s[0][0]) : nil
      @last_day =  last_day_s&.first&.first ? Date.parse(last_day_s[0][0]) : nil

      @total_days = 0
      @total_days = (@last_day - @first_day).to_i if @first_day && @last_day

      @source_files   = db.execute "SELECT distinct(filename) from LogLine"

      @log_size       = db.execute "SELECT count(datetime) from LogLine"
      @log_size       = @log_size[0][0]

      @selfpolls_size = db.execute "SELECT count(datetime) from LogLine where ip == '::1'"
      @selfpolls_size = @selfpolls_size[0][0]

      @crawlers_size  = db.execute "SELECT count(datetime) from LogLine where bot == 1"
      @crawlers_size = @crawlers_size[0][0]

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
        (options[:from_date] ? "date(datetime) >= '#{options[:from_date]}'" : nil),
        (options[:to_date] ? "date(datetime) <= '#{options[:to_date]}'" : nil),
        (options[:only_crawlers] ? "bot == 1" : nil),
        (options[:ignore_crawlers] ? "bot == 0" : nil),
        (options[:no_selfpolls] ? "ip != '::1'" : nil),
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
        case cast (strftime('%w', datetime) as integer)
          when 0 then 'Sunday'
          when 1 then 'Monday'
          when 2 then 'Tuesday'
          when 3 then 'Wednesday'
          when 4 then 'Thursday'
          when 5 then 'Friday'
          else 'Saturday'
        end as dow
      EOS

      @total_hits = db.execute "SELECT count(datetime) from LogLine where #{filter}"
      @total_hits = @total_hits[0][0]

      @total_unique_visits = db.execute "SELECT count(distinct(unique_visitor)) from LogLine where #{filter}"
      @total_unique_visits = @total_unique_visits[0][0]

      @total_size = db.execute "SELECT #{human_readable_size} from LogLine where #{filter}"
      @total_size = @total_size[0][0]

      @daily_distribution = db.execute "SELECT date(datetime), #{human_readable_day}, count(datetime), count(distinct(unique_visitor)), #{human_readable_size} from LogLine  where #{filter} group by date(datetime)"
      @time_distribution = db.execute "SELECT strftime('%H', datetime), count(datetime), count(distinct(unique_visitor)), #{human_readable_size} from LogLine  where #{filter} group by strftime('%H', datetime)"

      good_statuses = "(status like '2%' or status like '3%')"
      bad_statuses = "(status like '4%' or status like '5%')"
      html_page = "(extension like '.htm%')"
      non_html_page = "(extension not like '.htm%')"

      @most_requested_pages = db.execute "SELECT path, count(path), count(distinct(unique_visitor)), #{human_readable_size}, status from LogLine where #{good_statuses} and #{html_page} and #{filter} group by path order by count(path) desc limit #{options[:limit]}"
      @most_requested_resources = db.execute "SELECT path, count(path), count(distinct(unique_visitor)), #{human_readable_size}, status from LogLine where #{good_statuses} and #{non_html_page} and #{filter} group by path order by count(path) desc limit #{options[:limit]}"

      @missed_pages = db.execute "SELECT path, count(path), count(distinct(unique_visitor)), status from LogLine where #{bad_statuses} and #{html_page} and #{filter} group by path order by count(path) desc limit #{options[:limit]}"
      @missed_resources = db.execute "SELECT path, count(path), count(distinct(unique_visitor)), status from LogLine where #{bad_statuses} and #{filter} group by path order by count(path) desc limit #{options[:limit]}"

      @statuses = db.execute "SELECT status, count(status) from LogLine where #{filter} group by status order by status"

      @by_day_4xx = db.execute "SELECT date(datetime), count(datetime) from LogLine where substr(status, 1,1) == '4' and #{filter} group by date(datetime)"
      @by_day_3xx = db.execute "SELECT date(datetime), count(datetime) from LogLine where substr(status, 1,1) == '3' and #{filter} group by date(datetime)"
      @by_day_2xx = db.execute "SELECT date(datetime), count(datetime) from LogLine where substr(status, 1,1) == '2' and #{filter} group by date(datetime)"

      @statuses_by_day = (@by_day_2xx + @by_day_3xx + @by_day_4xx).group_by { |x| x[0] }.to_a.map { |x|
        [x[0], x[1].map { |y| y[1] }].flatten
      }

      @browsers = db.execute "SELECT browser, count(browser), count(distinct(unique_visitor)), #{human_readable_size} from LogLine where #{filter} group by browser order by count(browser) desc"
      @platforms = db.execute "SELECT platform, count(platform), count(distinct(unique_visitor)), #{human_readable_size} from LogLine where #{filter} group by platform order by count(platform) desc"
      @referers = db.execute "SELECT referer, count(referer), count(distinct(unique_visitor)), #{human_readable_size} from LogLine where #{filter} group by referer order by count(referer) desc limit #{options[:limit]}"
      
      @ips = db.execute "SELECT ip, count(ip), count(distinct(unique_visitor)), #{human_readable_size} from LogLine where #{filter} group by ip order by count(ip) desc limit #{options[:limit]}"

      @streaks = db.execute "SELECT ip, substr(datetime, 1, 10), path from LogLine order by ip, datetime"
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

