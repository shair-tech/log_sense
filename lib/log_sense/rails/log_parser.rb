require "sqlite3"

module LogSense
  module Rails
    #
    # parse a Rails log file and return a in-memory SQLite3 DB
    #
    class LogParser
      #
      # Tell users which format I can parse
      #
      def provide
        [:rails]
      end

      def parse(streams, options = {})
        db = SQLite3::Database.new ":memory:"
        
        db.execute <<-EOS
        CREATE TABLE IF NOT EXISTS Event(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          exit_status TEXT,
          started_at TEXT,
          ended_at TEXT,
          log_id TEXT,
          ip TEXT,
          unique_visitor TEXT,
          url TEXT,
          controller TEXT,
          html_verb TEXT,
          status INTEGER,
          duration_total_ms FLOAT,
          duration_views_ms FLOAT,
          duration_ar_ms FLOAT,
          allocations INTEGER,
          comment TEXT,
          source_file TEXT,
          line_number INTEGER
         )
        EOS

        ins = db.prepare <<-EOS
        insert into Event(
          exit_status,
          started_at,
          ended_at,
          log_id,
          ip,
          unique_visitor,
          url,
          controller,
          html_verb,
          status,
          duration_total_ms,
          duration_views_ms,
          duration_ar_ms,
          allocations,
          comment,
          source_file,
          line_number
         )
         values (#{Array.new(17, "?").join(", ")})
        EOS

        db.execute <<-EOS
        CREATE TABLE IF NOT EXISTS Error(
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         log_id TEXT,
         context TEXT,
         description TEXT,
         filename TEXT,
         line_number INTEGER
        )
        EOS

        ins_error = db.prepare <<-EOS
        insert into Error(
         log_id,
         context,
         description,
         filename,
         line_number
        )
        values (?, ?, ?, ?, ?)
        EOS

        db.execute <<-EOS
        CREATE TABLE IF NOT EXISTS Render(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          partial TEXT,
          duration_ms FLOAT,
          allocations INTEGER,
          filename TEXT,
          line_number INTEGER
        )
        EOS

        ins_rendered = db.prepare <<-EOS
        insert into Render(
         partial,
         duration_ms,
         allocations,
         filename,
         line_number

        # requests in the log might be interleaved.
        #
        # We use the 'pending' variable to progressively store data
        # about requests till they are completed; whey they are
        # complete, we enter the entry in the DB and remove it from the
        # hash
        pending = {}

        # Log lines are either one of:
        #
        # LOG_LEVEL, [ZULU_TIMESTAMP #NUMBER] INFO --: [ID] Started VERB "URL" for IP at TIMESTAMP
        # LOG_LEVEL, [ZULU_TIMESTAMP #NUMBER] INFO --: [ID] Processing by CONTROLLER as FORMAT
        # LOG_LEVEL, [ZULU_TIMESTAMP #NUMBER] INFO --: [ID] Parameters: JSON
        # LOG_LEVEL, [ZULU_TIMESTAMP #NUMBER] INFO --: [ID] Rendered VIEW within LAYOUT (Duration: DURATION | Allocations: ALLOCATIONS)
        # LOG_LEVEL, [ZULU_TIMESTAMP #NUMBER] INFO --: [ID] Completed STATUS STATUS_STRING in DURATION (Views: DURATION | ActiveRecord: DURATION | Allocations: NUMBER)
        #
        # and they appears in the order shown above: started, processing, ...
        #
        # Different requests might be interleaved, of course
        #
        streams.each do |stream|
          stream.readlines.each_with_index do |line, line_number|
            filename = stream == $stdin ? "stdin" : stream.path

            #
            # These are for development logs
            #

            data = match_and_process_rendered line
            if data
              ins_rendered.execute(
                data[:partial], data[:duration], data[:allocations],
                filename, line_number
              )
            end

            #
            # 
            #

            # I and F for completed requests, [ is for error messages
            next if line[0] != 'I' and line[0] != 'F' and line[0] != '['

            data = match_and_process_error line
            if data
              ins_error.execute(data[:log_id],
                                data[:context],
                                data[:description],
                                filename,
                                line_number)
              next
            end
            
            data = match_and_process_start line
            if data
              id = data[:log_id]
              pending[id] = data.merge(pending[id] || {})
              next
            end

            data = match_and_process_processing_by line
            if data
              id = data[:log_id]
              pending[id] = data.merge(pending[id] || {})
              next
            end

            data = match_and_process_fatal line
            if data
              id = data[:log_id]
              # it might as well be that the first event started before
              # the log.  With this, we make sure we add only events whose
              # start was logged and parsed
              if pending[id]
                event = data.merge(pending[id] || {})

                ins.execute(
                  event[:exit_status],
                  event[:started_at],
                  event[:ended_at],
                  event[:log_id],
                  event[:ip],
                  unique_visitor_id(event),
                  event[:url],
                  event[:controller],
                  event[:html_verb],
                  event[:status],
                  event[:duration_total_ms],
                  event[:duration_views_ms],
                  event[:duration_ar_ms],
                  event[:allocations],
                  event[:comment],
                  filename,
                  line_number
                )

                pending.delete(id)
              end
            end

            data = self.match_and_process_completed line
            if data
              id = data[:log_id]

              # it might as well be that the first event started before
              # the log.  With this, we make sure we add only events whose
              # start was logged and parsed
              if pending[id]
                event = data.merge (pending[id] || {})

                ins.execute(
                  event[:exit_status],
                  event[:started_at],
                  event[:ended_at],
                  event[:log_id],
                  event[:ip],
                  unique_visitor_id(event),
                  event[:url],
                  event[:controller],
                  event[:html_verb],
                  event[:status],
                  event[:duration_total_ms],
                  event[:duration_views_ms],
                  event[:duration_ar_ms],
                  event[:allocations],
                  event[:comment],
                  filename,
                  line_number
                )

                pending.delete(id)
              end
            end
          end
        end
        
        db
      end

      TIMESTAMP = /(?<timestamp>[^ ]+)/
      ID = /(?<id>[a-z0-9-]+)/
      VERB = /(?<verb>GET|POST|PATCH|PUT|DELETE)/
      URL = /(?<url>[^"]+)/
      IP = /(?<ip>[0-9.]+)/
      STATUS = /(?<status>[0-9]+)/
      STATUS_IN_WORDS = /(OK|Unauthorized|Found|Internal Server Error|Bad Request|Method Not Allowed|Request Timeout|Not Implemented|Bad Gateway|Service Unavailable)/
      MSECS = /[0-9.]+/

      # Error Messages
      # [584cffcc-f1fd-4b5c-bb8b-b89621bd4921] ActionController::RoutingError (No route matches [GET] "/assets/foundation-icons.svg"):
      # [fd8df8b5-83c9-48b5-a056-e5026e31bd5e] ActionView::Template::Error (undefined method `all_my_ancestor' for nil:NilClass):
      # [d17ed55c-f5f1-442a-a9d6-3035ab91adf0] ActionView::Template::Error (undefined method `volunteer_for' for #<DonationsController:0x007f4864c564b8>
      EXCEPTION = /[A-Za-z_0-9:]+(Error)?/
      ERROR_REGEXP = /^\[#{ID}\] (?<context>#{EXCEPTION}) \((?<description>(#{EXCEPTION})?.*)\):/

      def match_and_process_error(line)
        matchdata = ERROR_REGEXP.match line
        if matchdata
          {
            log_id: matchdata[:id],
            context: matchdata[:context],
            description: matchdata[:description]
          }
        end
      end

      # I, [2021-10-19T08:16:34.343858 #10477]  INFO -- : [67103c0d-455d-4fe8-951e-87e97628cb66] Started GET "/grow/people/471" for 217.77.80.35 at 2021-10-19 08:16:34 +0000
      STARTED_REGEXP = /I, \[#{TIMESTAMP} #[0-9]+\]  INFO -- : \[#{ID}\] Started #{VERB} "#{URL}" for #{IP} at/

      def match_and_process_start(line)
        matchdata = STARTED_REGEXP.match line
        if matchdata
          {
            started_at: matchdata[:timestamp],
            log_id: matchdata[:id],
            html_verb: matchdata[:verb],
            url: matchdata[:url],
            ip: matchdata[:ip]
          }
        end
      end

      # TODO: Add regexps for the performance data (Views ...). We have three cases (view, active records, allocations), (views, active records), (active records, allocations)
      # I, [2021-10-19T08:16:34.712331 #10477]  INFO -- : [67103c0d-455d-4fe8-951e-87e97628cb66] Completed 200 OK in 367ms (Views: 216.7ms | ActiveRecord: 141.3ms | Allocations: 168792)
      # I, [2021-12-09T16:53:52.657727 #2735058]  INFO -- : [0064e403-9eb2-439d-8fe1-a334c86f5532] Completed 200 OK in 13ms (Views: 11.1ms | ActiveRecord: 1.2ms)
      # I, [2021-12-06T14:28:19.736545 #2804090]  INFO -- : [34091cb5-3e7b-4042-aaf8-6c6510d3f14c] Completed 500 Internal Server Error in 66ms (ActiveRecord: 8.0ms | Allocations: 24885)
      COMPLETED_REGEXP = /I, \[#{TIMESTAMP} #[0-9]+\]  INFO -- : \[#{ID}\] Completed #{STATUS} #{STATUS_IN_WORDS} in (?<total>#{MSECS})ms \((Views: (?<views>#{MSECS})ms \| )?ActiveRecord: (?<arec>#{MSECS})ms( \| Allocations: (?<alloc>[0-9]+))?\)/

      def match_and_process_completed(line)
        matchdata = (COMPLETED_REGEXP.match line)
        # exit_status = matchdata[:status].to_i == 500 ? "E" : "I"
        if matchdata
          {
            exit_status: "I",
            ended_at: matchdata[:timestamp],
            log_id: matchdata[:id],
            status: matchdata[:status],
            duration_total_ms: matchdata[:total],
            duration_views_ms: matchdata[:views],
            duration_ar_ms: matchdata[:arec],
            allocations: matchdata[:alloc],
            comment: ""
          }
        end
      end

      # I, [2021-10-19T08:16:34.345162 #10477]  INFO -- : [67103c0d-455d-4fe8-951e-87e97628cb66] Processing by PeopleController#show as HTML
      PROCESSING_REGEXP = /I, \[#{TIMESTAMP} #[0-9]+\]  INFO -- : \[#{ID}\] Processing by (?<controller>[^ ]+) as/

      def match_and_process_processing_by line
        matchdata = PROCESSING_REGEXP.match line
        if matchdata
          {
            log_id: matchdata[:id],
            controller: matchdata[:controller]
          }
        end
      end

      # F, [2021-12-04T00:34:05.838973 #2735058] FATAL -- : [3a16162e-a6a5-435e-a9d8-c4df5dc0f728]   
      # F, [2021-12-04T00:34:05.839157 #2735058] FATAL -- : [3a16162e-a6a5-435e-a9d8-c4df5dc0f728] ActionController::RoutingError (No route matches [GET] "/wp/wp-includes/wlwmanifest.xml"):
      # F, [2021-12-04T00:34:05.839209 #2735058] FATAL -- : [3a16162e-a6a5-435e-a9d8-c4df5dc0f728]   
      # F, [2021-12-04T00:34:05.839269 #2735058] FATAL -- : [3a16162e-a6a5-435e-a9d8-c4df5dc0f728] actionpack (5.2.4.4) lib/action_dispatch/middleware/debug_exceptions.rb:65:in `call'
      FATAL_REGEXP = /F, \[#{TIMESTAMP} #[0-9]+\] FATAL -- : \[#{ID}\] (?<comment>.*)$/

      def match_and_process_fatal(line)
        matchdata = FATAL_REGEXP.match line
        if matchdata
          {
            exit_status: "F",
            log_id: matchdata[:id],
            comment: matchdata[:comment]
          }
        end
      end

      # Started GET "/projects?locale=it" for 127.0.0.1 at 2024-06-06 23:23:31 +0200
      # Processing by EmployeesController#index as HTML
      #   Parameters: {"locale"=>"it"}
      # [...]
      # Completed 200 OK in 135ms (Views: 128.0ms | ActiveRecord: 2.5ms | Allocations: 453450)
      #
      # Started GET "/serviceworker.js" for 127.0.0.1 at 2024-06-06 23:23:29 +0200
      # ActionController::RoutingError (No route matches [GET] "/serviceworker.js"):
      #
      #
      # Started POST "/projects?locale=it" for 127.0.0.1 at 2024-06-06 23:34:33 +0200
      # Processing by ProjectsController#create as TURBO_STREAM
      # Parameters: {"authenticity_token"=>"[FILTERED]", "project"=>{"name"=>"AA", "funding_agency"=>"", "total_cost"=>"0,00", "personnel_cost"=>"0,00", "percentage_funded"=>"0", "from_date"=>"2024-01-01", "to_date"=>"2025-12-31", "notes"=>""}, "commit"=>"Crea Progetto", "locale"=>"it"}
      #
      # Completed   in 48801ms (ActiveRecord: 17.8ms | Allocations: 2274498)
      # Completed 422 Unprocessable Entity in 16ms (Views: 5.1ms | ActiveRecord: 2.0ms | Allocations: 10093)
      #
      # Completed 500 Internal Server Error in 24ms (ActiveRecord: 1.4ms | Allocations: 4660)
      # ActionView::Template::Error (Error: Undefined variable: "$white".
      #         on line 6:28 of app/assets/stylesheets/_animations.scss
      #         from line 16:9 of app/assets/stylesheets/application.scss
      # >>   from { background-color: $white; }
      
      #    ---------------------------^
      # ):
      #      9:     = csrf_meta_tags
      #     10:     = csp_meta_tag
      #     11: 
      #     12:     = stylesheet_link_tag "application", "data-turbo-track": "reload"
      #     13:     = javascript_importmap_tags
      #     14: 
      #     15:   %body
      #
      # app/views/layouts/application.html.haml:12
      # app/controllers/application_controller.rb:26:in `switch_locale'

      # Rendered devise/sessions/_project_partial.html.erb (Duration: 78.4ms | Allocations: 88373)
      # Rendered devise/sessions/new.html.haml within layouts/application (Duration: 100.0ms | Allocations: 104118)
      # Rendered application/_favicon.html.erb (Duration: 2.6ms | Allocations: 4454)
      # Rendered layouts/_manage_notice.html.erb (Duration: 0.3ms | Allocations: 193)
      # Rendered layout layouts/application.html.erb (Duration: 263.4ms | Allocations: 367467)
      # Rendered donations/_switcher.html.haml (Duration: 41.1ms | Allocations: 9550)
      # Rendered donations/_status_header.html.haml (Duration: 1.4ms | Allocations: 3192)
      # Rendered donations/_status_header.html.haml (Duration: 0.0ms | Allocations: 7)
      RENDERED_REGEXP = /^ *Rendered (?<partial>[^ ]+) .*\(Duration: (?<duration>[0-9.]+)ms \| Allocations: (?<allocations>[0-9]+)\)$/

      def match_and_process_rendered(line)
        matchdata = RENDERED_REGEXP.match line
        if matchdata
          {
            partial: matchdata[:partial],
            duration: matchdata[:duration],
            allocations: matchdata[:allocations]
          }
        end
      end

      # generate a unique visitor id from an event
      def unique_visitor_id(event)
        date = event[:started_at] || event[:ended_at] || "1970-01-01"
        "#{DateTime.parse(date).strftime("%Y-%m-%d")} #{event[:ip]}"
      end
    end
  end
end
