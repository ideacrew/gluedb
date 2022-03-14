module Parsers
  module Edi
    class ImportCache
      def initialize
        @plan_cache = Hash.new
        Plan.all.each do |p|
          @plan_cache[p.year] ||= {}
          @plan_cache[p.year][p.hios_plan_id] = p 
        end
        @carrier_fein_cache = Carrier.all.inject({}) do |acc, c|
          c.carrier_profiles.each do |c_prof|
            acc[c_prof.fein] = c
          end
          acc
        end
      end

      def lookup_plan(h_id, year)
        return nil unless @plan_cache.has_key?(year)
        @plan_cache[year][h_id]
      end

      def lookup_carrier_fein(c_fein)
        @carrier_fein_cache[c_fein]
      end
    end
  end
end
