module Parsers
  module Edi
    module Etf
      class EtfLoop
        def initialize(etf_loop)
          @loop = etf_loop
        end

        def subscriber_loop
          found = @loop["L2000s"].detect do |l2000|
            l2000["INS"][2].strip == "18"
          end

          PersonLoop.new(found)
        end

        def carrier_fein
          @loop["L1000B"]["N1"][4]
        end

        def employer_loop
          @loop["L1000A"]["N1"]
        end

        def is_shop?
          !(@loop["L1000A"]["N1"][4] == ExchangeInformation.receiver_id)
        end

        def people
          @loop['L2000s'].map { |p| PersonLoop.new(p) }
        end

        def cancellation_or_termination?
          people.any? { |p| p.cancellation_or_termination? }
        end
      end
    end
  end
end