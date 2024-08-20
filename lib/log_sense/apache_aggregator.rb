module LogSense
  class ApacheAggregator < Aggregator
    def initialize(db, options = { limit: 900 })
      @table = "LogLine"
      @date_field = "datetime"
      @url_field = "path"

      @db = db
      @options = options
    end

    #
    # take a sqlite3 database and analyze data
    #
    # @ variables are automatically put in the returned data
    #
    def aggregate
      aggregate_log_info
      aggregate_statuses
      aggregate_ips

      #
      # Addition info specific to Apache Log Files
      #
      sp = @db.execute "SELECT count(datetime) from LogLine where ip == '::1'"
      @selfpolls_size = sp[0][0]

      cw = @db.execute "SELECT count(datetime) from LogLine where bot == 1"
      @crawlers_size = cw[0][0]

      ts = @db.execute "SELECT #{human_readable_size} from LogLine where #{filter}"
      @total_size = ts[0][0]

      html = "(extension like '.htm%')"
      non_html = "(extension not like '.htm%')"
      gs = "(status like '2%' or status like '3%')"
      bs = "(status like '4%' or status like '5%')"

      @daily_distribution = @db.execute "SELECT date(datetime),
                                          #{human_readable_day},
                                          count(datetime),
                                          count(distinct(unique_visitor)),
                                          #{human_readable_size}
                                          from LogLine
                                          where (#{filter} and #{html})
                                          group by date(datetime)"

      @time_distribution = @db.execute "SELECT strftime('%H', datetime),
                                               count(datetime),
                                               count(distinct(unique_visitor)),
                                               #{human_readable_size} from LogLine
                                               where (#{filter} and #{html})
                                               group by strftime('%H', datetime)"

      @most_requested_pages = @db.execute resource_query(html, gs)
      @most_requested_resources = @db.execute resource_query(non_html, gs)
      @missed_pages = @db.execute resource_query(html, bs)
      @missed_resources = @db.execute resource_query(non_html, bs)

      @missed_pages_by_ip = @db.execute "SELECT ip, path, status from LogLine
                                           where #{filter} and #{html} and #{bs}
                                           limit #{@options[:limit]}"

      @missed_resources_by_ip = @db.execute "SELECT ip, path, status
                                             from LogLine
                                             where #{filter} and #{bs}
                                             limit #{@options[:limit]}"

      @browsers = @db.execute "SELECT browser,
                                      count(browser),
                                      count(distinct(unique_visitor)),
                                      #{human_readable_size} from LogLine
                                      where #{filter} and #{html}
                                      group by browser
                                      order by count(browser) desc"

      @platforms = @db.execute "SELECT platform,
                                       count(platform),
                                       count(distinct(unique_visitor)),
                                       #{human_readable_size} from LogLine
                                       where #{filter} and #{html}
                                       group by platform
                                       order by count(platform) desc"

      @combined_platforms = @db.execute "SELECT browser,
                                                platform,
                                                ip,
                                                count(datetime),
                                                #{human_readable_size}
                                                from LogLine
                                                where #{filter} and #{html}
                                                group by browser, platform, ip
                                                order by count(datetime) desc
                                                limit #{@options[:limit]}"

      @referers = @db.execute "SELECT referer,
                                      count(referer),
                                      count(distinct(unique_visitor)),
                                      #{human_readable_size} from LogLine
                                      where #{filter} and #{html}
                                      group by referer
                                      order by count(referer)
                                      desc limit #{@options[:limit]}"
      
      instance_vars_to_hash
    end

    private

    def resource_query(type, result)
      "SELECT path,
              count(path),
              count(distinct(unique_visitor)),
              #{human_readable_size}, status from LogLine
       where #{filter} and #{result} and #{type}
       group by path
       order by count(path) desc
       limit #{@options[:limit]}"
    end
  end
end
