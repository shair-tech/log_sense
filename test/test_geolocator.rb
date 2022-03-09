require 'minitest/autorun'

require 'log_sense.rb'

class DataCruncherTest < Minitest::Test
  # not really a test, more of a script to check what goes on
  def test_geolocation
    input_files = [File.open('sample_logs/spmbook_com.log', 'r')]
    db = LogSense::ApacheLogParser.parse input_files
    data = LogSense::ApacheDataCruncher.crunch db, { limit: 30 }
    data = LogSense::IpLocator.geolocate data

    assert_equal 'United States of America', data[:ips][0][4], 'Maybe GeoIp changed?'
    assert_equal 'United States of America', data[:ips][1][4], 'Maybe GeoIp changed?'
    assert_equal 'Palestine, State of', data[:ips].last[4], 'Maybe GeoIp changed?'
  end
end
