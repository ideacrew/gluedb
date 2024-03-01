module Parsers::Xml::Enrollment
  class ChangeRequest
    def initialize(xml)
      @xml = xml
      @namespaces = Parsers::Xml::Enrollment::NAMESPACES

      @payload = @xml.at_xpath('//proc:payload', @namespaces)
    end

    def type
      @xml.at_xpath('/proc:Operation/proc:operation/proc:type', @namespaces).text
    end

    def market_type
      @payload.first_element_child.name.split('_').first
    end

    def individual_market?
      market_type == 'individual'
    end

    def subscriber_id
      @enrollment_group.at_xpath('./ins:subscriber/ins:exchange_member_id', @namespaces).text
    end

    def cancel?
      type == 'cancel'
    end

    def terminate?
      type == 'terminate'
    end

    def reinstate?
      type == 'reinstate'
    end

    def reason
      @xml.at_xpath('/proc:Operation/proc:operation/proc:reason', @namespaces)
    end

    def market
      @payload.first_element_child.name.split('_').first #individual or shop
    end

    def affected_member_ids
      affected_members = @xml.at_xpath('/proc:Operation/proc:operation/proc:affected_members', @namespaces)
      member_id_elements = affected_members.xpath('./proc:member_id', @namespaces)

      member_ids = []
      member_id_elements.each do |element|
        member_ids << element.text
      end
      member_ids
    end

    def hios_plan_id
      raise NotImplementedError
    end

    def premium_amount_total
      raise NotImplementedError
    end

    def enrollees
      raise NotImplementedError
    end

    def credit
      raise NotImplementedError
    end

    def total_responsible_amount
      raise NotImplementedError
    end

    def enrollee_premium_sum
      sum = 0
      enrollees.each { |e| sum += e.premium_amount}
      sum
    end

    def affected_enrollees_sum
      sum = 0
      affected_enrollees.each { |e| sum += e.premium_amount }
      sum
    end

    def affected_enrollees
      enrollees.select do |e|
        affected_member_ids.include?(e.hbx_member_id)
      end
    end

    def subscriber_affected?
      affected_enrollees.any? { |e| e.hbx_member_id == subscriber_id}
    end
  end
end
