module LogSense
  module Apache
    # parses a log line and returns a hash
    # LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\"" combined
    #
    # %h: IP
    # %l: ident or -
    # %u: userid or -
    # %t: [10/Oct/2000:13:55:36 -0700]
    #   day = 2*digit
    #   month = 3*letter
    #   year = 4*digit
    #   hour = 2*digit
    #   minute = 2*digit
    #   second = 2*digit
    #   zone = (`+' | `-') 4*digit
    # %r: GET /apache_pb.gif HTTP/1.0
    # %{User-agent}: "
    #
    # Example
    # 116.179.32.16 - - [19/Dec/2021:22:35:11 +0100] "GET / HTTP/1.1" 200 135 "-" "Mozilla/5.0 (compatible; Baiduspider/2.0; +http://www.baidu.com/search/spider.html)"
    #
    class LogLineParser
      DAY = "[0-9]{2}"
      MONTH = "[A-Za-z]{3}"
      YEAR = "[0-9]{4}"
      TIMEC = "[0-9]{2}"
      TIMEZONE = "(\\+|-)[0-9]{4}"

      IP = "(?<ip>[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}|::1|unknown)"
      IDENT = "(?<ident>[^ ]+|-)"
      USERID = "(?<userid>[^ ]+|-)"

      TIMESTAMP = "(?<date>#{DAY}\\/#{MONTH}\\/#{YEAR}):(?<time>#{TIMEC}:#{TIMEC}:#{TIMEC} #{TIMEZONE})"

      HTTP_METHODS = "GET|HEAD|POST|PUT|DELETE|CONNECT|OPTIONS|TRACE|PATCH"
      WEBDAV_METHODS = "COPY|LOCK|MKCOL|MOVE|PROPFIND|PROPPATCH|UNLOCK"
      OTHER_METHODS = "SEARCH|REPORT|PRI|HEAD/robots.txt"
      METHOD = "(?<method>#{HTTP_METHODS}|#{WEBDAV_METHODS}|#{OTHER_METHODS})"
      PROTOCOL = "(?<protocol>HTTP\/[0-9]\.[0-9]|-|.*)"
      URL = "(?<url>[^ ]+)"
      REFERER = '(?<referer>[^"]*)'
      RETURN_CODE = "(?<status>[1-5][0-9][0-9])"
      SIZE = "(?<size>[0-9]+|-)"
      USER_AGENT = '(?<user_agent>[^"]*)'

      attr_reader :format

      def initialize
        @format = /#{IP} #{IDENT} #{USERID} \[#{TIMESTAMP}\] "(#{METHOD} #{URL} #{PROTOCOL}|-|.+)" #{RETURN_CODE} #{SIZE} "#{REFERER}" "#{USER_AGENT}"/o
      end

      def parse(line)
        @format.match(line) ||
          raise("Apache LogLine Parser Error: Could not parse #{line}")
      end
    end
  end
end
