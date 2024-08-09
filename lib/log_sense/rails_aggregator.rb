module LogSense
  class RailsAggregator < Aggregator
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
                 group by controller, method, request_format
      )

      #
      # Browser Info data
      #
      @browsers = @db.execute %Q(
          SELECT browser as Browser,
                 count(distinct(id)) as Visits
                 from BrowserInfo
                 group by browser
      )

      @platforms = @db.execute %Q(
          SELECT platform as Platform,
                 count(distinct(id)) as Visits
                 from BrowserInfo
                 group by platform
      )

      @fatal = @db.execute %Q(
          SELECT strftime("%Y-%m-%d %H:%M", started_at),
                 ip,
                 url,
                 error.description,
                 event.log_id
                 FROM Event JOIN Error
                 ON event.log_id == error.log_id
                 WHERE #{filter} and exit_status == 'F').gsub("\n", "") || [[]]

      @fatal_plot = @db.execute %Q(
          SELECT strftime("%Y-%m-%d", started_at) as Day,
                 count(distinct(event.id)) as Errors
                 FROM Event JOIN Error
                 ON event.log_id == error.log_id
                 WHERE #{filter} and exit_status == 'F'
                 GROUP BY strftime("%Y-%m-%d", started_at)).gsub("\n", "") || [[]]

      @internal_server_error = @db.execute %Q(
         SELECT strftime("%Y-%m-%d %H:%M", started_at), status, ip, url,
                error.description,
                event.log_id
                FROM Event JOIN Error
                ON event.log_id == error.log_id
                WHERE #{filter} and substr(status, 1, 1) == '5').gsub("\n", "") || [[]]

      @error = @db.execute %Q(
         SELECT filename,
                log_id, description, count(log_id)
                FROM Error
                WHERE (description NOT LIKE '%No route matches%' and
                       description NOT LIKE '%Couldn''t find%')
                GROUP BY description).gsub("\n", "") || [[]]
      
      @possible_attacks = @db.execute %Q(
         SELECT filename,
                log_id, description, count(log_id)
                FROM Error
                WHERE (description LIKE '%No route matches%' or
                       description LIKE '%Couldn''t find%')
                GROUP BY description).gsub("\n", "") || [[]]

      instance_vars_to_hash
    end
  end
end
