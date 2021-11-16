require 'minitest/autorun'

require 'log_sense/apache_log_parser'
require 'log_sense/apache_data_cruncher'
require 'log_sense/ip_locator'

class DataCruncherTest < Minitest::Test
  # not really a test, more of a script to check what goes on
  def test_geolocation
    db = LogSense::ApacheLogParser.parse 'sample_logs/spmbook_com.log'
    data = LogSense::ApacheDataCruncher.crunch db, { limit: 30 }
    data = LogSense::IpLocator.geolocate data

    assert_equal "United States of America", data[:ips][0][4], "Maybe GeoIp changed?"
    assert_equal "United States of America", data[:ips][1][4], "Maybe GeoIp changed?"
    assert_equal "Palestine, State of", data[:ips].last[4], "Maybe GeoIp changed?"

  end
end
