module Parsers::Xml::Enrollment
  class ChangeRequestFactory
    def self.create_from_xml(doc)
      payload = doc.at_xpath('/proc:Operation/proc:payload', NAMESPACES)
      market_type = payload.first_element_child.name.split('_').first

      case market_type
      when 'individual'
        IndividualChangeRequest.new(doc)
      when 'shop'
        ShopChangeRequest.new(doc)
      end
    end
  end
end

