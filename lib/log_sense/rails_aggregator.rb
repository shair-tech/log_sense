module LogSense
  class RailsAggregator < Aggregator
    WORDS_SEPARATOR = ' · '

    def initialize(db, options = { limit: 900 })
      @table = "Event"
      @date_field = "started_at"
      @url_field = "url"

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

      @daily_distribution = @db.execute %(
          SELECT date(started_at), #{human_readable_day}, count(started_at)
                 from Event
                 where #{filter}
                 group by date(started_at)).gsub("\n", "")

      @time_distribution = @db.execute %(
          SELECT strftime("%H", started_at), count(started_at) from Event
                 where #{filter}
                 group by strftime('%H', started_at)).gsub("\n", "")

      @performance = @db.execute %(
          SELECT distinct(controller),
                 count(controller),
                 printf("%.2f", min(duration_total_ms)),
                 printf("%.2f", avg(duration_total_ms)),
                 printf("%.2f", max(duration_total_ms))
                 from Event
                 where #{filter}
                 group by controller order by controller).gsub("\n", "")

      #
      # Use the performance information to build a tree map.
      # We then compute by device and show the treemap and the table by device
      # together
      #

      # ["CompletedSurveysController#new", 14, "22.00", "51.57", "116.00"]
      controller_and_methods = @performance.group_by { |element|
        (element[0] || "#").split("#")[0]
      }

      @controller_and_methods_treemap = controller_and_methods.map do |key, values|
        {
          name: key,
          value: values.map { |value| value[1] || 0.0 }.inject(&:+),
          children: values.map { |value|
            {
              name: (value[0] || "#").split("#")[1],
              value: value[1]
            }
          }
        }
      end

      @controller_and_methods_by_device = @db.execute %Q(
          SELECT controller as Controller,
                 method as Method,
                 request_format as Format,
                 sum(iif(platform = 'ios', 1, 0)) as iOS,
                 sum(iif(platform = 'android', 1, 0)) as Android,
                 sum(iif(platform = 'mac', 1, 0)) as Mac,
                 sum(iif(platform = 'windows', 1, 0)) as Windows,
                 sum(iif(platform = 'linux', 1, 0)) as Linux,
                 sum(iif(platform != 'ios' and platform != 'android' and platform != 'mac' and platform != 'windows' and platform != 'linux', 1, 0)) as Other,
                 count(distinct(id)) as Total
                 from BrowserInfo
                 where #{filter}
                 group by controller, method, request_format
      )

      #
      # Browser Info data
      #
      @browsers = @db.execute %Q(
          SELECT browser as Browser,
                 count(distinct(id)) as Visits
                 from BrowserInfo
                 where #{filter}
                 group by browser
      )

      @platforms = @db.execute %Q(
          SELECT platform as Platform,
                 count(distinct(id)) as Visits
                 from BrowserInfo
                 where #{filter}
                 group by platform
      )

      @fatal_plot = @db.execute %(
          SELECT strftime("%Y-%m-%d", started_at) as Day,
                 sum(distinct(event.id)) as Errors,
                 sum(iif(context LIKE '%ActionController::RoutingError%', 1, 0)) as RoutingErrors,
                 sum(iif(context NOT LIKE '%ActionController::RoutingError%', 1, 0)) as OtherErrors
                 FROM Event JOIN Error
                 ON event.log_id == error.log_id
                 WHERE #{filter} and exit_status == 'F'
                 GROUP BY strftime("%Y-%m-%d", started_at)
      ).gsub("\n", "") || [[]]

      @fatal = @db.execute %(
          SELECT strftime("%Y-%m-%d %H:%M", started_at),
                 ip,
                 url,
                 context,
                 description,
                 event.log_id
                 FROM Event JOIN Error
                 ON event.log_id == error.log_id
                 WHERE #{filter} and exit_status == 'F'
      ).gsub("\n", "") || [[]]

      @fatal_grouped = @db.execute %(
         SELECT filename,
                group_concat(log_id, '#{WORDS_SEPARATOR}'),
                context,
                description,
                count(distinct(error.id))
                FROM Error
                GROUP BY description
      ).gsub("\n", "") || [[]]
      
      instance_vars_to_hash
    end
  end
end
