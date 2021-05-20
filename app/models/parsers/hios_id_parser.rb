module Parsers
  class HiosIdParser
    def self.parse(hios_id_string)
      return "" if hios_id_string.blank?
      return hios_id_string if (hios_id_string =~ /-/) || (hios_id_string.length < 15)
      (hios_id_string[0..-3] + "-" + hios_id_string[-2..-1])
    end
  end
end