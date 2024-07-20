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

      @fatal = @db.execute %Q(
          SELECT strftime("%Y-%m-%d %H:%M", started_at),
                 ip,
                 url,
                 error.description,
                 event.log_id
                 FROM Event JOIN Error
                 ON event.log_id == error.log_id
                 WHERE #{filter} and exit_status == 'F').gsub("\n", "") || [[]]

      @internal_server_error = @db.execute %Q(
         SELECT strftime("%Y-%m-%d %H:%M", started_at), status, ip, url,
                error.description,
                event.log_id
                FROM Event JOIN Error
                ON event.log_id == error.log_id
                WHERE #{filter} and substr(status, 1, 1) == '5').gsub("\n", "") || [[]]

      @error = @db.execute %Q(
         SELECT filename, log_id, context, description, count(log_id)
                FROM Error
                GROUP BY description).gsub("\n", "") || [[]]
      
      instance_vars_to_hash
    end
  end
end
