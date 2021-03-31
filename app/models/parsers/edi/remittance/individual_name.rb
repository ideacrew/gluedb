module Parsers
  module Edi
    module Remittance
      class IndividualName
        def initialize(l2100)
          @loop = l2100
        end

        def enrollment_group_id
          @loop["REFs"].detect do |ref|
            ref[1] == "POL"
          end[2]
        end

        def hios_plan_id
          hios_value = (@loop["REFs"].detect do |ref|
            ref[1] == "TV"
          end[2])
          ::Parsers::HiosIdParser.parse(hios_value)
        end
      end
    end
  end
end
