require 'sqlite3'

module LogSense
  module RailsLogParser
    def self.parse filename, options = {}
      content = filename ? File.readlines(filename) : ARGF.readlines

      db = SQLite3::Database.new ":memory:"
      db.execute 'CREATE TABLE IF NOT EXISTS Event(
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
         comment TEXT
      )'
      
      ins = db.prepare("insert into Event(
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
         comment
      )
      values (#{Array.new(15, '?').join(', ')})")

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
      
      File.readlines(filename).each do |line|
        # We discard LOG_LEVEL != 'I'
        next if line[0] != 'I' and line[0] != 'F'
        
        data = self.match_and_process_start line
        if data
          id = data[:log_id]
          pending[id] = data.merge (pending[id] || {})
          next
        end

        data = self.match_and_process_processing_by line
        if data
          id = data[:log_id]
          pending[id] = data.merge (pending[id] || {})
          next
        end

        data = self.match_and_process_fatal line
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
              "#{DateTime.parse(event[:started_at] || event[:ended_at]).strftime("%Y-%m-%d")} #{event[:ip]}",
              event[:url],
              event[:controller],
              event[:html_verb],
              event[:status],
              event[:duration_total_ms],
              event[:duration_views_ms],
              event[:duration_ar_ms],
              event[:allocations],
              event[:comment]
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
              "#{DateTime.parse(event[:started_at] || event[:ended_at]).strftime("%Y-%m-%d")} #{event[:ip]}",
              event[:url],
              event[:controller],
              event[:html_verb],
              event[:status],
              event[:duration_total_ms],
              event[:duration_views_ms],
              event[:duration_ar_ms],
              event[:allocations],
              event[:comment]
            )

            pending.delete(id)
          end
        end


        data = self.match_and_process_completed_no_alloc line
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
              "#{DateTime.parse(event[:ended_at]).strftime("%Y-%m-%d")} #{event[:ip]}",
              event[:url],
              event[:controller],
              event[:html_verb],
              event[:status],
              event[:duration_total_ms],
              event[:duration_views_ms],
              event[:duration_ar_ms],
              event[:allocations],
              event[:comment]
            )

            pending.delete(id)
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
    MSECS = /[0-9.]+/

    # I, [2021-10-19T08:16:34.343858 #10477]  INFO -- : [67103c0d-455d-4fe8-951e-87e97628cb66] Started GET "/grow/people/471" for 217.77.80.35 at 2021-10-19 08:16:34 +0000
    STARTED_REGEXP = /I, \[#{TIMESTAMP} #[0-9]+\]  INFO -- : \[#{ID}\] Started #{VERB} "#{URL}" for #{IP} at/

    def self.match_and_process_start line
      matchdata = STARTED_REGEXP.match line
      if matchdata
        {
          started_at: matchdata[:timestamp],
          log_id: matchdata[:id],
          html_verb: matchdata[:verb],
          url: matchdata[:url],
          ip: matchdata[:ip]
        }
      else
        nil
      end
    end

    # I, [2021-10-19T08:16:34.712331 #10477]  INFO -- : [67103c0d-455d-4fe8-951e-87e97628cb66] Completed 200 OK in 367ms (Views: 216.7ms | ActiveRecord: 141.3ms | Allocations: 168792)
    COMPLETED_REGEXP = /I, \[#{TIMESTAMP} #[0-9]+\]  INFO -- : \[#{ID}\] Completed #{STATUS} [^ ]+ in (?<total>#{MSECS})ms \(Views: (?<views>#{MSECS})ms \| ActiveRecord: (?<arec>#{MSECS})ms \| Allocations: (?<alloc>[0-9]+)\)/

    def self.match_and_process_completed line
      matchdata = (COMPLETED_REGEXP.match line)
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
      else
        nil
      end
    end

    # I, [2021-12-09T16:53:52.657727 #2735058]  INFO -- : [0064e403-9eb2-439d-8fe1-a334c86f5532] Completed 200 OK in 13ms (Views: 11.1ms | ActiveRecord: 1.2ms)
    COMPLETED_NO_ALLOC_REGEXP = /I, \[#{TIMESTAMP} #[0-9]+\]  INFO -- : \[#{ID}\] Completed #{STATUS} [^ ]+ in (?<total>#{MSECS})ms \(Views: (?<views>#{MSECS})ms \| ActiveRecord: (?<arec>#{MSECS})ms\)/

    def self.match_and_process_completed_no_alloc line
      matchdata = (COMPLETED_NO_ALLOC_REGEXP.match line)
      if matchdata
        {
          exit_status: "I",
          ended_at: matchdata[:timestamp],
          log_id: matchdata[:id],
          status: matchdata[:status],
          duration_total_ms: matchdata[:total],
          duration_views_ms: matchdata[:views],
          duration_ar_ms: matchdata[:arec],
          allocations: -1,
          comment: ""
        }
      else
        nil
      end
    end


    # I, [2021-10-19T08:16:34.345162 #10477]  INFO -- : [67103c0d-455d-4fe8-951e-87e97628cb66] Processing by PeopleController#show as HTML
    PROCESSING_REGEXP = /I, \[#{TIMESTAMP} #[0-9]+\]  INFO -- : \[#{ID}\] Processing by (?<controller>[^ ]+) as/

    def self.match_and_process_processing_by line
      matchdata = PROCESSING_REGEXP.match line
      if matchdata
        {
          log_id: matchdata[:id],
          controller: matchdata[:controller]
        }
      else
        nil
      end
    end

    # F, [2021-12-04T00:34:05.838973 #2735058] FATAL -- : [3a16162e-a6a5-435e-a9d8-c4df5dc0f728]   
    # F, [2021-12-04T00:34:05.839157 #2735058] FATAL -- : [3a16162e-a6a5-435e-a9d8-c4df5dc0f728] ActionController::RoutingError (No route matches [GET] "/wp/wp-includes/wlwmanifest.xml"):
    # F, [2021-12-04T00:34:05.839209 #2735058] FATAL -- : [3a16162e-a6a5-435e-a9d8-c4df5dc0f728]   
    # F, [2021-12-04T00:34:05.839269 #2735058] FATAL -- : [3a16162e-a6a5-435e-a9d8-c4df5dc0f728] actionpack (5.2.4.4) lib/action_dispatch/middleware/debug_exceptions.rb:65:in `call'
    FATAL_REGEXP = /F, \[#{TIMESTAMP} #[0-9]+\] FATAL -- : \[#{ID}\] (?<comment>.*)$/

    def self.match_and_process_fatal line
      matchdata = FATAL_REGEXP.match line
      if matchdata
        {
          exit_status: "F",
          log_id: matchdata[:id],
          comment: matchdata[:comment]
        }
      else
        nil
      end
    end

  end

end

