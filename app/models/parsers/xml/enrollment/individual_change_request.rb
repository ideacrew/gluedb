module Parsers::Xml::Enrollment
  class IndividualChangeRequest < ChangeRequest
    def initialize(xml)
      super(xml)
      @enrollment_group = @payload.at_xpath('./ins:individual_market_enrollment_group', @namespaces)
      @plan = @enrollment_group.at_xpath('./ins:plan', @namespaces)
      @carrier = @enrollment_group.at_xpath('./ins:carrier', @namespaces)
    end

    def eg_id
      @enrollment_group.at_xpath('./ins:exchange_policy_id', @namespaces).text
    end

    def hios_plan_id
      @plan.at_xpath('./pln:plan/pln:hios_plan_id', @namespaces).text
    end

    def hbx_carrier_id
      @carrier.at_xpath('./car:carrier/car:exchange_carrier_id', @namespaces).text
    end

    def carrier_id
      @carrier.at_xpath('./ins:carrier_id', @namespaces).text
    end

    def plan_year
      subscriber = Parsers::Xml::Enrollment::IndividualEnrollee.new(@enrollment_group.xpath('./ins:subscriber', @namespaces))
      begin
      Date.parse(subscriber.rate_period_date).year
      rescue
        subscriber.rate_period_date.year
      end
    end

    def begin_date
      begin_date = @enrollment_group.at_xpath('./ins:subscriber/ins:coverage/ins:benefit_begin_date', @namespaces).text
      Date.strptime(begin_date.to_s, '%Y%m%d')
    end

    def plan_id
      @plan.at_xpath('./ins:plan_id', @namespaces).text
    end

    def premium_amount_total
      @plan.at_xpath('./ins:premium_amount_total', @namespaces).text.to_f
    end

    def enrollees
      enrollees = @enrollment_group.xpath('./ins:subscriber | ./ins:member', @namespaces)
      enrollees.collect { |e| Parsers::Xml::Enrollment::IndividualEnrollee.new(e) }
    end

    def credit
      @plan.at_xpath('./ins:aptc_amount', @namespaces).text.to_f
    end

    def total_responsible_amount
      @plan.at_xpath('./ins:total_responsible_amount', @namespaces).text.to_f
    end
  end
end
