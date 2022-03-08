require 'csv'
require 'sqlite3'
require 'ipaddr'
require 'iso_country_codes'

module LogSense
  #
  # Populate table of IP Locations from dbip-country-lite
  #
  module IpLocator
    DB_FILE = File.join(File.dirname(__FILE__), '..', '..', 'ip_locations', 'dbip-country-lite.sqlite3')

    def self.dbip_to_sqlite(db_location)
      db = SQLite3::Database.new ':memory:'
      db.execute 'CREATE TABLE ip_location (
        from_ip_n INTEGER,
        from_ip TEXT,
        to_ip TEXT,
        country_code TEXT
      )'

      ins = db.prepare 'INSERT INTO ip_location(from_ip_n, from_ip, to_ip, country_code) values (?, ?, ?, ?)'
      CSV.foreach(db_location) do |row|
        ip = IPAddr.new row[0]
        ins.execute(ip.to_i, row[0], row[1], row[2])
      end

      # persist to file
      ddb = SQLite3::Database.new(DB_FILE)
      b = SQLite3::Backup.new(ddb, 'main', db, 'main')
      b.step(-1) #=> DONE
      b.finish
    end

    def self.load_db
      SQLite3::Database.new DB_FILE
    end

    def self.locate_ip(ip, db)
      return unless ip

      begin
        ip_n = IPAddr.new(ip).to_i
        res = db.execute "SELECT * FROM ip_location where from_ip_n <= #{ip_n} order by from_ip_n desc limit 1"
        IsoCountryCodes.find(res[0][3]).name
      rescue IPAddr::InvalidAddressError
        'INVALID IP'
      rescue IsoCountryCodes::UnknownCodeError
        res[0][3]
      end
    end

    #
    # add country code to data[:ips]
    #
    def self.geolocate(data)
      @location_db = IpLocator.load_db

      data[:ips].each do |ip|
        country_code = IpLocator.locate_ip ip[0], @location_db
        ip << country_code
      end
      data
    end
  end
end
