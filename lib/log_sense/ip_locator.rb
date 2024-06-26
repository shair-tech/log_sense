require "csv"
require "sqlite3"
require "ipaddr"
require "iso_country_codes"

module LogSense
  #
  # Populate table of IP Locations from dbip-country-lite
  #
  module IpLocator
    DB_FILE = File.join(File.dirname(__FILE__), "..", "..", "ip_locations", "dbip-country-lite.sqlite3")

    def self.dbip_to_sqlite(db_location)
      db = SQLite3::Database.new ":memory:"
      db.execute "CREATE TABLE ip_location (
        from_ip_n INTEGER,
        from_ip TEXT,
        to_ip TEXT,
        country TEXT
      )"

      ins = db.prepare "INSERT INTO ip_location(
                               from_ip_n, from_ip, to_ip, country)
                               values (?, ?, ?, ?)"
      CSV.foreach(db_location) do |row|
        # skip ip v6 addresses
        next if row[0].include?(":")

        ip = IPAddr.new row[0]
        country_code = row[2]

        begin
          country = IsoCountryCodes.find(country_code).name
        rescue IsoCountryCodes::UnknownCodeError
          country = country_code
        end
        
        ins.execute(ip.to_i, row[0], row[1], country)
      end

      # persist to file
      ddb = SQLite3::Database.new(DB_FILE)
      b = SQLite3::Backup.new(ddb, "main", db, "main")
      b.step(-1) #=> DONE
      b.finish
    end

    def merge(parser_db)
      Sqlite3::Database.open DB_FILE
      parser_db
    end

    def self.load_db
      SQLite3::Database.new DB_FILE
    end

    def self.locate_ip(ip, db)
      return unless ip

      query = db.prepare "SELECT * FROM ip_location
                            where from_ip_n <= ?
                            order by from_ip_n desc limit 1"
      begin
        ip_n = IPAddr.new(ip).to_i
        result_set = query.execute ip_n
        result_set.map { |x| x[3] }[0]
      rescue IPAddr::InvalidAddressError
        "INVALID IP"
      end
    end

    #
    # add country code to data[:ips]
    #
    def self.geolocate(data)
      @location_db = IpLocator.load_db

      data[:ips].map do |line|
        begin
          country_code = IpLocator.locate_ip line[0], @location_db
          line + [country_code]
        rescue
          line + ["INVALID IP"]
        end
      end
    end
  end
end
