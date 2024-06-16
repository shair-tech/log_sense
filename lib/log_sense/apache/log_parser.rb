require "sqlite3"
require "browser"
require_relative "log_line_parser"

module LogSense
  module Apache
    #
    # parse an Apache log file and return a SQLite3 DB
    #
    class LogParser
      def parse(streams, options = {})
        db = SQLite3::Database.new ":memory:"

        db.execute "CREATE TABLE IF NOT EXISTS LogLine(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      datetime TEXT,
      ip TEXT,
      user TEXT,
      unique_visitor TEXT,
      method TEXT,
      path TEXT,
      extension TEXT,
      status TEXT,
      size INTEGER,
      referer TEXT,
      user_agent TEXT,
      bot INTEGER,
      browser TEXT,
      browser_version TEXT,
      platform TEXT,
      platform_version TEXT,
      source_file TEXT,
      line_number INTEGER
      )"

        ins = db.prepare("insert into LogLine (
                datetime,
                ip,
                user,
                unique_visitor,
                method,
                path,
                extension,
                status,
                size,
                referer,
                user_agent,
                bot,
                browser,
                browser_version,
                platform,
                platform_version,
                source_file,
                line_number
                )
              values (#{Array.new(18, '?').join(', ')})")

        parser = LogLineParser.new

        streams.each do |stream|
          stream.readlines.each_with_index do |line, line_number|
            begin
              hash = parser.parse line
              ua = Browser.new(hash[:user_agent], accept_language: 'en-us')
              ins.execute(
                DateTime.parse("#{hash[:date]}T#{hash[:time]}").iso8601,
                hash[:ip],
                hash[:userid],
                unique_visitor_id(hash),
                hash[:method],
                hash[:url],
                (hash[:url] ? File.extname(hash[:url]) : ''),
                hash[:status],
                hash[:size].to_i,
                hash[:referer],
                hash[:user_agent],
                ua.bot? ? 1 : 0,
                (ua.name || ''),
                (ua.version || ''),
                (ua.platform.name || ''),
                (ua.platform.version || ''),
                stream == $stdin ? "stdin" : stream.path,
                line_number
              )
            rescue StandardError => e
              warn e.message
            end
          end
        end

        db
      end

      private

      def unique_visitor_id hash
        "#{hash[:date]} #{hash[:ip]} #{hash[:user_agent]}"
      end
    end
  end
end
