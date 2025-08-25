# frozen_string_literal: true

module LogSense
  module FormattingUtil
    ##
    # Number with thousand separator
    #
    def self.with_thousands(number, separator: ",", comma: ".")
      return unless number
          
      decimal, fraction = number.to_s.split(comma)
      with_thousands = decimal.reverse.gsub(/(\d\d\d)/, "\\1#{separator}")

      "#{with_thousands.reverse}#{comma if fraction}#{fraction}"
    end
  end
end
