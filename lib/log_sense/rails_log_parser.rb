require 'sqlite3'

module LogSense
  module RailsLogParser
    def self.parse filename, options = {}
      content = filename ? File.readlines(filename) : ARGF.readlines

      db = SQLite3::Database.new ":memory:"
      db.execute 'CREATE TABLE IF NOT EXISTS Event(
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         started_at TEXT,
         ended_at TEXT,
         log_id TEXT,
         ip TEXT,
         url TEXT,
         controller TEXT,
         html_verb TEXT,
         status INTEGER, 
         duration_total_ms FLOAT,
         duration_views_ms FLOAT,
         duration_ar_ms FLOAT,
         allocations INTEGER
      )'
      
      ins = db.prepare("insert into Event(
         started_at,
         ended_at,
         log_id,
         ip,
         url,
         controller,
         html_verb,
         status, 
         duration_total_ms,
         duration_views_ms,
         duration_ar_ms,
         allocations)
      values (#{Array.new(12, '?').join(', ')})")

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
        next if line[0] != 'I'
        
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

        data = self.match_and_process_completed line
        if data
          id = data[:log_id]

          # it might as well be that the first event started before
          # the log.  With this, we make sure we add only events whose
          # start was logged and parsed
          if pending[id]
            event = data.merge (pending[id] || {})

            ins.execute(
              event[:started_at],
              event[:ended_at],
              event[:log_id],
              event[:ip],
              event[:url],
              event[:controller],
              event[:html_verb],
              event[:status],
              event[:duration_total_ms],
              event[:duration_views_ms],
              event[:duration_ar_ms],
              event[:allocations]
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
      matchdata = COMPLETED_REGEXP.match line
      if matchdata
        {
          ended_at: matchdata[:timestamp],
          log_id: matchdata[:id],
          status: matchdata[:status],
          duration_total_ms: matchdata[:total],
          duration_views_ms: matchdata[:views],
          duration_ar_ms: matchdata[:arec],
          allocations: matchdata[:alloc],
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

  end

end

