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
        CREATE TABLE IF NOT EXISTS BrowserInfo(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          browser TEXT,
          platform TEXT,
          device_name TEXT,
          controller TEXT,
          method TEXT,
          request_format TEXT,
          anon_ip TEXT,
          started_at TEXT
        )
        EOS

        ins_browser_info = db.prepare <<-EOS
        insert into BrowserInfo(
         browser,
         platform,
         device_name,
         controller,
         method,
         request_format,
         anon_ip,
         started_at
        )
        values (?, ?, ?, ?, ?, ?, ?, ?)
        EOS

        # jobs
        db.execute <<-EOS
        CREATE TABLE IF NOT EXISTS Job(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          started_at TEXT,
          ended_at TEXT,
          duration_total_ms FLOAT,
          worker TEXT,
          host TEXT,
          pid TEXT,
          log_id TEXT,
          job_id TEXT,
          object_id TEXT,
          method TEXT,
          arguments TEXT,
          exit_status TEXT,
          attempt INTEGER,
          error_msg TEXT,
          source_file TEXT,
          line_number INTEGER
         )
        EOS

        ins_job = db.prepare <<-EOS
        insert into Job(
          started_at,
          ended_at,
          duration_total_ms,
          worker,
          host,
          pid,
          log_id,
          job_id,
          object_id,
          method,
          arguments,
          exit_status,
          attempt,
          error_msg,
          source_file,
          line_number
         )
         values (#{Array.new(16, "?").join(", ")})
        EOS

        # requests in the log might be interleaved.
        #
        # We use the 'pending' variable to progressively store data
        # about requests till they are completed; whey they are
        # complete, we enter the entry in the DB and remove it from the
        # hash
        pending = {}

        # for delayed jobs
        pending_jobs = {}

        # Fatal explanation messages span several lines (2, 4, ?)
        #
        # We keep a Hash with the FATAL explanation messages and we persist when
        # the parsing ends
        fatal_explanation_messages = {}

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

            # I, F are for completed and failed requests, [ is for the FATAL
            # error message explanation
            next unless ['I', 'F', 'E', '['].include? line[0]

            data = match_and_process_browser_info line
            if data
              ins_browser_info.execute(data[:browser],
                                       data[:platform],
                                       data[:device_name],
                                       data[:controller],
                                       data[:method],
                                       data[:request_format],
                                       data[:anon_ip],
                                       data[:timestamp])
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

            # fatal message is alternative to completed and is used to insert an
            # Event
            data = match_and_process_fatal line
            if data
              id = data[:log_id]
              if pending[id]
                # data last, so that we respect, for instance, the 'F' state
                event = pending[id].merge(data)
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

            data = match_and_process_completed line
            if data
              id = data[:log_id]

              # it might as well be that the first event started before
              # the log.  With this, we make sure we add only events whose
              # start was logged and parsed
              if pending[id]
                # data last, so that we respect the most recent data (the last
                # log line)
                event = pending[id].merge(data)

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

            # fatal_explanations are multiple lines with a description of the
            # fatal error and they all use the ID of the FATAL event (so that
            # we can later join)
            data = match_and_process_fatal_explanation line
            if data
              previous = fatal_explanation_messages[data[:log_id]]
              
              # keep adding to the explanation
              fatal_explanation_messages[data[:log_id]] = [
                data[:log_id],
                [previous ? previous[1] : "", data[:context]].compact.join(" "),
                [previous ? previous[2] : "", data[:description]].compact.join(" "),
                filename,
                line_number
              ]
              next
            end

            #
            # Match enqueuing job
            #
            data = match_and_process_enqueuing_job line
            if data
              id = data[:job_id]
              pending_jobs[id] = data.merge(pending_jobs[id] || {})
              next
            end

            #
            # Match running
            # 
            data = match_and_process_running_job line
            if data
              id = data[:job_id]
              # change the key to pid
              pid = data[:object_id]
              pending_jobs[pid] = data.merge(pending_jobs[id] || {})

              pending_jobs.delete(id)
              next
            end

            #
            # Match completed
            # 
            data = match_and_process_completed_job line
            if data
              id = data[:object_id]
              # it has to be there!
              if pending_jobs[id]
                data = (pending_jobs[id] || {}).merge(data)
              end
              
              ins_job.execute(
                data[:started_at],
                data[:ended_at],
                data[:duration_total_ms],
                data[:worker],
                data[:host],
                data[:pid],
                data[:log_id],
                data[:job_id], # no longer necessary
                data[:object_id], # completed jobs are destroyed
                data[:method],
                data[:arguments],
                data[:exit_status],
                data[:attempt],
                data[:error_msg],
                filename,
                line_number
              )
              pending_jobs.delete(id)
              next
            end

            #
            # Match job errors
            #
            data = match_and_process_job_error line
            if data
              id = data[:object_id]
              # TODO: no need for if (here and everywhere else)
              # it has to be there!
              if pending_jobs[id]
                data = (pending_jobs[id] || {}).merge(data)
              end
              
              ins_job.execute(
                data[:started_at],
                data[:ended_at],
                nil,
                data[:worker],
                data[:host],
                data[:pid],
                data[:log_id],
                "",
                data[:object_id],
                data[:method],
                data[:arguments],
                data[:exit_status],
                data[:attempt],
                data[:error_msg],
                filename,
                line_number
              )

              pending_jobs.delete(id)
            end
          end
        end
        
        # persist the fatal error messages
        # TODO massive update
        fatal_explanation_messages.values.map do |value|
          ins_error.execute(value)
        end

        # DO NOT persist the pending_jobs which have not yet completed (those
        # still available at: pending_jobs).
        #
        # In fact various entries initiated with RUNNING end up with "performed"
        # (rather than COMPLETED).  Notice that entries COMPLETED always have a
        # peformed entry as well.
        #
        # Since we do not yet process "performed" entry log and in pending jobs
        # we end up accumulating a bunch of entries which are marked as
        # "performed"
        #
        # Performed entries are tricky since they use JOB_ID, rather than the
        # object_id and probably requires to change how we enter pending_ids

        db
      end

      # could be private here, I guess we keep them public to make them simpler
      # to try from irb
      
      TIMESTAMP = '(?<timestamp>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]+)'
      LOG_ID = '(?<log_id>[a-z0-9-]+)'
      VERB = '(?<verb>GET|POST|PATCH|PUT|DELETE)'
      URL = '(?<url>[^"]+)'
      IP = '(?<ip>[0-9.]+)'
      STATUS = '(?<status>[0-9]+)'
      STATUS_IN_WORDS = '(OK|Unauthorized|Found|Internal Server Error|Bad Request|Method Not Allowed|Request Timeout|Not Implemented|Bad Gateway|Service Unavailable)'
      MSECS = '[0-9.]+'

      # I, [2021-10-19T08:16:34.343858 #10477]  INFO -- : [67103c0d-455d-4fe8-951e-87e97628cb66] Started GET "/grow/people/471" for 217.77.80.35 at 2021-10-19 08:16:34 +0000
      STARTED_REGEXP = /I, \[#{TIMESTAMP} #[0-9]+\]  INFO -- : \[#{LOG_ID}\] Started #{VERB} "#{URL}" for #{IP} at/o

      def match_and_process_start(line)
        matchdata = STARTED_REGEXP.match line
        if matchdata
          {
            started_at: matchdata[:timestamp],
            log_id: matchdata[:log_id],
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
      COMPLETED_REGEXP = /I, \[#{TIMESTAMP} #[0-9]+\]  INFO -- : \[#{LOG_ID}\] Completed #{STATUS} #{STATUS_IN_WORDS} in (?<total>#{MSECS})ms \((Views: (?<views>#{MSECS})ms \| )?ActiveRecord: (?<arec>#{MSECS})ms( \| Allocations: (?<alloc>[0-9]+))?\)/o

      def match_and_process_completed(line)
        matchdata = (COMPLETED_REGEXP.match line)
        # exit_status = matchdata[:status].to_i == 500 ? "E" : "I"
        if matchdata
          {
            exit_status: "S:COMPLETED",
            ended_at: matchdata[:timestamp],
            log_id: matchdata[:log_id],
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
      PROCESSING_REGEXP = /I, \[#{TIMESTAMP} #[0-9]+\]  INFO -- : \[#{LOG_ID}\] Processing by (?<controller>[^ ]+) as/o

      def match_and_process_processing_by line
        matchdata = PROCESSING_REGEXP.match line
        if matchdata
          {
            log_id: matchdata[:log_id],
            controller: matchdata[:controller]
          }
        end
      end

      # F, [2021-12-04T00:34:05.838973 #2735058] FATAL -- : [3a16162e-a6a5-435e-a9d8-c4df5dc0f728]   
      # F, [2021-12-04T00:34:05.839157 #2735058] FATAL -- : [3a16162e-a6a5-435e-a9d8-c4df5dc0f728] ActionController::RoutingError (No route matches [GET] "/wp/wp-includes/wlwmanifest.xml"):
      # F, [2021-12-04T00:34:05.839209 #2735058] FATAL -- : [3a16162e-a6a5-435e-a9d8-c4df5dc0f728]   
      # F, [2021-12-04T00:34:05.839269 #2735058] FATAL -- : [3a16162e-a6a5-435e-a9d8-c4df5dc0f728] actionpack (5.2.4.4) lib/action_dispatch/middleware/debug_exceptions.rb:65:in `call'

      FATAL_REGEXP = /F, \[#{TIMESTAMP} #[0-9]+\] FATAL -- : \[#{LOG_ID}\]/o

      def match_and_process_fatal(line)
        matchdata = FATAL_REGEXP.match line
        if matchdata
          {
            exit_status: "S:FAILED",
            log_id: matchdata[:log_id],
          }
        end
      end

      # Explanation of what caused a FATAL event.  List of lines starting with the
      # ID of the fatal event and providing some sort of explanation.
      #
      # Notice that we have more than one line per FATAL event
      #
      # [584cffcc-f1fd-4b5c-bb8b-b89621bd4921] ActionController::RoutingError (No route matches [GET] "/assets/foundation-icons.svg"):
      #
      # [fd8df8b5-83c9-48b5-a056-e5026e31bd5e] ActionView::Template::Error (undefined method `all_my_ancestor' for nil:NilClass):
      #
      # [d17ed55c-f5f1-442a-a9d6-3035ab91adf0] ActionView::Template::Error (undefined method `volunteer_for' for #<DonationsController:0x007f4864c564b8>
      #
      #, [2024-08-20T09:41:35.140725 #4151931] FATAL -- : [f57e3648-568a-48f9-ae3a-a522b1ff3298]   
      # [f57e3648-568a-48f9-ae3a-a522b1ff3298] NoMethodError (undefined method `available_quantity' for nil:NilClass
      # [f57e3648-568a-48f9-ae3a-a522b1ff3298]   
      # [f57e3648-568a-48f9-ae3a-a522b1ff3298] app/models/donations/donation.rb:462:in `block in build_items_for_delivery'
      # [f57e3648-568a-48f9-ae3a-a522b1ff3298] app/models/donations/donation.rb:440:in `build_items_for_delivery'
      # [f57e3648-568a-48f9-ae3a-a522b1ff3298] app/controllers/donations_controller.rb:1395:in `create_delivery'

      EXCEPTION = "[A-Za-z_0-9:]+(Error|NotFound|Invalid|Unknown|Missing|ENOSPC)"
      FATAL_EXPLANATION_REGEXP = /^\[#{LOG_ID}\] (?<context>#{EXCEPTION})?(?<description>.*)/o
      def match_and_process_fatal_explanation(line)
        matchdata = FATAL_EXPLANATION_REGEXP.match line
        if matchdata
          {
            log_id: matchdata[:log_id],
            context: matchdata[:context],
            description: matchdata[:description].gsub(/^ *\(/, "").gsub(/\):$/, "")
          }
        end
      end

      # I, [2024-07-01T02:21:34.339058 #1392909]  INFO -- : [815b3e28-8d6e-4741-8605-87654a9ff58c] BrowserInfo: "Unknown Browser","unknown_platform","Unknown","Devise::SessionsController","new","html","4db749654a0fcacbf3868f87723926e7405262f8d596e8514f4997dc80a3cd7e","2024-07-01T02:21:34+02:00"
      BROWSER_INFO_REGEXP = /BrowserInfo: "(?<browser>.+)","(?<platform>.+)","(?<device_name>.+)","(?<controller>.+)","(?<method>.+)","(?<request_format>.+)","(?<anon_ip>.+)","(?<timestamp>.+)"/o

      def match_and_process_browser_info(line)
        matchdata = BROWSER_INFO_REGEXP.match line
        if matchdata
          {
            browser: matchdata[:browser],
            platform: matchdata[:platform],
            device_name: matchdata[:device_name],
            controller: matchdata[:controller],
            method: matchdata[:method],
            request_format: matchdata[:request_format],
            anon_ip: matchdata[:anon_ip],
            started_at: matchdata[:timestamp],
          }
        end
      end

      # Sequence:
      #
      # - enqueued (LOG_ID user event, JOB_ID assigned by system)
      # - running  (JOB_ID links to enqueued; PID assigned by system; OBJECT_ID assigned by the system)
      # - performing (OBJECT_ID links to running;  OBJECT_ID assigned by the system; JOB_ID is new)
      # - (rendering)
      # - performed (OBJECT_ID  links to running; JOB_ID links to previous)
      # - completed (OBJECT_ID  links to running; JOB_ID links to previous)
      #
      # SOMETIMES PERFORMED APPEARS WITH NO COMPLETED.
      #
      # I, [2024-08-01T06:21:16.302152 #3569287]  INFO -- : [96d14192-c7cc-48a9-9df7-3786de20b085] [ActiveJob] Enqueued ActionMailer::Parameterized::DeliveryJob (Job ID: 01e82c5c-fb42-4e5f-b0a7-6fa9512a9fb5) to DelayedJob(mailers) with arguments: "MessageMailer", "build_message", "deliver_now", {:project_id=>1, :email_to=>"activpentrutine@gmail.com", :hash=>{:event_name=>"download", :subject=>"Aviz BRAC-MEGA240176", :download=>#<GlobalID:0x00007f02d8e1ad98 @uri=#<URI::GID gid://btf3/Download/10652>>, :group=>#<GlobalID:0x00007f02d8e1a820 @uri=#<URI::GID gid://btf3/Organization/10061>>}, :locale=>:ro}
      #
      # I, [2024-08-01T06:21:21.235006 #3563911]  INFO -- : 2024-08-01T06:21:21+0200: [Worker(delayed_job host:shair1 pid:3563911)] Job ActionMailer::Parameterized::DeliveryJob [01e82c5c-fb42-4e5f-b0a7-6fa9512a9fb5] from DelayedJob(mailers) with arguments: ["MessageMailer", "build_message", "deliver_now", {"project_id"=>1, "email_to"=>"activpentrutine@gmail.com", "hash"=>{"event_name"=>"download", "subject"=>"Aviz BRAC-MEGA240176", "download"=>{"_aj_globalid"=>"gid://btf3/Download/10652"}, "group"=>{"_aj_globalid"=>"gid://btf3/Organization/10061"}, "_aj_symbol_keys"=>["event_name", "subject", "download", "group"]}, "locale"=>{"_aj_serialized"=>"ActiveJob::Serializers::SymbolSerializer", "value"=>"ro"}, "_aj_symbol_keys"=>["project_id", "email_to", "hash", "locale"]}] (id=212885) (queue=mailers) RUNNING
      #
      # I, [2024-08-01T06:21:21.251282 #3563911]  INFO -- : [ActiveJob] [ActionMailer::Parameterized::DeliveryJob] [01e82c5c-fb42-4e5f-b0a7-6fa9512a9fb5] Performing ActionMailer::Parameterized::DeliveryJob (Job ID: 01e82c5c-fb42-4e5f-b0a7-6fa9512a9fb5) from DelayedJob(mailers) enqueued at 2024-08-01T04:21:16Z with arguments: "MessageMailer", "build_message", "deliver_now", {:project_id=>1, :email_to=>"activpentrutine@gmail.com", :hash=>{:event_name=>"download", :subject=>"Aviz BRAC-MEGA240176", :download=>#<GlobalID:0x00007fbb86760950 @uri=#<URI::GID gid://btf3/Download/10652>>, :group=>#<GlobalID:0x00007fbb86760220 @uri=#<URI::GID gid://btf3/Organization/10061>>}, :locale=>:ro}
      #
      # I, [2024-08-01T06:21:22.137863 #3563911]  INFO -- : [ActiveJob] [ActionMailer::Parameterized::DeliveryJob] [01e82c5c-fb42-4e5f-b0a7-6fa9512a9fb5] Performed ActionMailer::Parameterized::DeliveryJob (Job ID: 01e82c5c-fb42-4e5f-b0a7-6fa9512a9fb5) from DelayedJob(mailers) in 886.42ms
      #
      #
      # I, [2024-08-01T06:38:41.005687 #3563911]  INFO -- : 2024-08-01T06:38:41+0200: [Worker(delayed_job host:shair1 pid:3563911)] 1 jobs processed at 1.4476 j/s, 0 failed
      #
      #
      # I, [2024-08-01T06:21:22.141853 #3563911]  INFO -- : 2024-08-01T06:21:22+0200: [Worker(delayed_job host:shair1 pid:3563911)] Job ActionMailer::Parameterized::DeliveryJob [01e82c5c-fb42-4e5f-b0a7-6fa9512a9fb5] from DelayedJob(mailers) with arguments: ["MessageMailer", "build_message", "deliver_now", {"project_id"=>1, "email_to"=>"activpentrutine@gmail.com", "hash"=>{"event_name"=>"download", "subject"=>"Aviz BRAC-MEGA240176", "download"=>{"_aj_globalid"=>"gid://btf3/Download/10652"}, "group"=>{"_aj_globalid"=>"gid://btf3/Organization/10061"}, "_aj_symbol_keys"=>["event_name", "subject", "download", "group"]}, "locale"=>{"_aj_serialized"=>"ActiveJob::Serializers::SymbolSerializer", "value"=>"ro"}, "_aj_symbol_keys"=>["project_id", "email_to", "hash", "locale"]}] (id=212885) (queue=mailers) COMPLETED after 0.9067

      # Sequence with errors:
      # (two log entries per error)
      #
      # E, [2024-08-15T05:10:30.613623 #4150573] ERROR -- : [ActiveJob] [ActionMailer::Parameterized::DeliveryJob] [79ea42c0-d280-4cf9-b77e-65917d4bc9fc] Error performing ActionMailer::Parameterized::DeliveryJob (Job ID: 79ea42c0-d280-4cf9-b77e-65917d4bc9fc) from DelayedJob(mailers) in 462.62ms: Net::SMTPFatalError (553 Recipient domain not specified.

      # E, [2024-08-15T05:10:30.614189 #4150573] ERROR -- : 2024-08-15T05:10:30+0200: [Worker(delayed_job host:shair1 pid:4150573)] Job ActionMailer::Parameterized::DeliveryJob [79ea42c0-d280-4cf9-b77e-65917d4bc9fc] from DelayedJob(mailers) with arguments: ["MessageMailer", "build_message", "deliver_now", {"project_id"=>1, "email_to"=>"-", "hash"=>{"event_name"=>"download", "subject"=>"Aviz BvREWE240258.2", "download"=>{"_aj_globalid"=>"gid://btf3/Download/10877"}, "group"=>{"_aj_globalid"=>"gid://btf3/Organization/10060"}, "_aj_symbol_keys"=>["event_name", "subject", "download", "group"]}, "locale"=>{"_aj_serialized"=>"ActiveJob::Serializers::SymbolSerializer", "value"=>"ro"}, "_aj_symbol_keys"=>["project_id", "email_to", "hash", "locale"]}] (id=213242) (queue=mailers) FAILED (22 prior attempts) with Net::SMTPFatalError: 553 Recipient domain not specified.
      
      TIMESTAMP_WITH_TZONE = '(?<timestamp_tzone>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\\+[0-9]+)'
      ID = '(?<id>[0-9]+)'
      JOB_ID = '(?<job_id>[a-zA-Z0-9-]+)'
      WORKER = 'Worker\\((?<worker>.+) host:(?<host>.+) pid:(?<pid>[0-9]+)\\)'
      METHOD = '(?<method>[A-Za-z0-9:#_]+)'
      TIMES = '(?<attempt>[0-9]+)'
      ERROR_MSG = '(?<error_msg>.+)'
      ARGUMENTS = '(?<arguments>.+)'

      #
      # these are together, since they return temporary data
      #
      ENQUEUEING = /I, \[#{TIMESTAMP} #[0-9]+\]  INFO -- : \[#{LOG_ID}\] \[ActiveJob\] Enqueued #{METHOD} \(Job ID: #{JOB_ID}\) to .* with arguments: #{ARGUMENTS}/o

      def match_and_process_enqueuing_job(line)
        matchdata = ENQUEUEING.match line
        if matchdata
          {
            log_id: matchdata[:log_id],
            job_id: matchdata[:job_id]
          }
        end
      end

      RUNNING_MESSAGE = /I, \[#{TIMESTAMP} #[0-9]+\]  INFO -- : #{TIMESTAMP_WITH_TZONE}: \[#{WORKER}\] Job #{METHOD} \[#{JOB_ID}\] from .+ with arguments: \[#{ARGUMENTS}\] \(id=#{ID}\) \(queue=.*\) RUNNING/o

      def match_and_process_running_job(line)
        matchdata = RUNNING_MESSAGE.match line
        if matchdata
          {
            started_at: matchdata[:timestamp],
            job_id: matchdata[:job_id],
            object_id: matchdata[:id],
            pid: matchdata[:pid]
          }
        end
      end

      COMPLETED_MESSAGE = /I, \[#{TIMESTAMP} #[0-9]+\]  INFO -- : #{TIMESTAMP_WITH_TZONE}: \[#{WORKER}\] Job #{METHOD} \[#{JOB_ID}\] from .+ with arguments: \[#{ARGUMENTS}\] \(id=#{ID}\) \(queue=.*\) COMPLETED after (?<duration_total_ms>#{MSECS})/o

      def match_and_process_completed_job(line)
        matchdata = COMPLETED_MESSAGE.match line
        if matchdata
          {
            ended_at: matchdata[:timestamp],
            duration_total_ms: matchdata[:duration_total_ms],
            id: matchdata[:id],
            job_id: matchdata[:job_id],
            worker: matchdata[:worker],
            host: matchdata[:host],
            pid: matchdata[:pid],
            log_id: matchdata.named_captures["log_id"],
            object_id: matchdata[:id],
            method: matchdata[:method],
            exit_status: 'S:COMPLETED',
            arguments: matchdata[:arguments]
          }
        end
      end      
      
      # similar to completed with I->E, INFO->ERROR, COMPLETED->FAILED and final message structure a bit different
      ERROR_MESSAGE_PERMANENT = /E, \[#{TIMESTAMP} #[0-9]+\] ERROR -- : #{TIMESTAMP_WITH_TZONE}: \[#{WORKER}\] Job #{METHOD} \[#{JOB_ID}\] from .+ with arguments: \[#{ARGUMENTS}\] \(id=#{ID}\) \(queue=.*\) (?<error_msg>FAILED permanently because of #{TIMES} consecutive failures)/o

      ERROR_MESSAGE = /E, \[#{TIMESTAMP} #[0-9]+\] ERROR -- : #{TIMESTAMP_WITH_TZONE}: \[#{WORKER}\] Job #{METHOD} \[#{JOB_ID}\] from .+ with arguments: \[#{ARGUMENTS}\] \(id=#{ID}\) \(queue=.*\) FAILED \(#{TIMES} prior attempts\) with #{ERROR_MSG}/o

      ERROR_MESSAGE_SHORT = /E, \[#{TIMESTAMP} #[0-9]+\] ERROR -- : #{TIMESTAMP_WITH_TZONE}: \[#{WORKER}\] Job #{METHOD} \(id=#{ID}\) FAILED \(#{TIMES} prior attempts\) with #{ERROR_MSG}/o

      def match_and_process_job_error(line)
        [ERROR_MESSAGE_PERMANENT, ERROR_MESSAGE, ERROR_MESSAGE_SHORT].map do |regexp|
          matchdata = regexp.match line
          if matchdata
            exit_status = if matchdata[:error_msg].include?("permanently")
                            "S:FAILED"
                          else
                            "S:ERROR"
                          end

            return {
              ended_at: matchdata[:timestamp],
              duration_total_ms: nil, # we could compute the time to failure
              worker: matchdata[:worker],
              host: matchdata[:host],
              pid: matchdata[:pid],
              job_id: matchdata.named_captures["job_id"],
              object_id: matchdata[:id],
              method: matchdata[:method],
              arguments: matchdata.named_captures["arguments"],
              exit_status:,
              attempt: matchdata[:attempt],
              error_msg: matchdata[:error_msg],
            }
          end
        end

        nil
      end

      # generate a unique visitor id from an event
      def unique_visitor_id(event)
        date = event[:started_at] || event[:ended_at] || "1970-01-01"
        "#{DateTime.parse(date).strftime("%Y-%m-%d")} #{event[:ip]}"
      end
    end
  end
end
