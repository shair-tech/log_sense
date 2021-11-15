require 'apache_log/parser'
require 'sqlite3'
require 'browser'

module LogSense
  module ApacheLogParser
    #
    # parse an Apache log file and return a SQLite3 DB
    #

    def self.parse filename, options = {}
      content = filename ? File.readlines(filename) : ARGF.readlines

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
      platform_version TEXT)"
      
      ins = db.prepare('insert into LogLine (
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
                platform_version)
              values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)')

      parser = ApacheLog::Parser.new(options[:format] || 'combined')
      
      content.each do |line|
        begin
          hash = parser.parse line

          ua = Browser.new(hash[:user_agent], accept_language: "en-us")
          ins.execute(
            hash[:datetime].iso8601,
            hash[:remote_host],
            hash[:user],
            hash[:datetime].strftime("%Y-%m-%d") + " " + hash[:remote_host] + " " + hash[:user_agent],
            hash[:request][:method],
            hash[:request][:path],
            (hash[:request][:path] ? File.extname(hash[:request][:path]) : ""),
            hash[:status],
            hash[:size].to_i,
            hash[:referer],
            hash[:user_agent],
            ua.bot? ? 1 : 0,
            (ua.name || ""),
            (ua.version || ""),
            (ua.platform.name || ""),
            (ua.platform.version || "")
          )
        rescue
          STDERR.puts "Apache Log parser error: could not parse #{line}"
        end
      end
      
      db
    end

  end
end
