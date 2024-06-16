module LogSense
  #
  # Check options and return appropriate error if
  # combinations of command arguments are wrong
  #
  module Options
    module Checker
      SUPPORTED_CHAINS = {
        rails: %i[txt html sqlite3 ufw],
        apache: %i[txt html sqlite3 ufw]
      }.freeze

      def self.compatible?(iformat, oformat)
        (SUPPORTED_CHAINS[iformat.to_sym] || []).include? oformat.to_sym
      end

      def self.chains_to_s
        string = ""
        SUPPORTED_CHAINS.each do |iformat, oformat|
          string << "- #{iformat}: #{oformat.join(", ")}\n"
        end
        string
      end
    end
  end
end
