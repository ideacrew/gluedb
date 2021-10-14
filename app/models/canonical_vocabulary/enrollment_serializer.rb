module CanonicalVocabulary
  class EnrollmentSerializer
    XMLNSES = {
      "xmlns:con"=>"http://dchealthlink.com/vocabularies/1/contact",
      "xmlns:bt"=>"http://dchealthlink.com/vocabularies/1/base_types",
      "xmlns:emp"=>"http://dchealthlink.com/vocabularies/1/employer",
      "xmlns:pln"=>"http://dchealthlink.com/vocabularies/1/plan",
      "xmlns:ins"=>"http://dchealthlink.com/vocabularies/1/insured",
      "xmlns:car"=>"http://dchealthlink.com/vocabularies/1/carrier",
      "xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance"
    }

    attr_reader :policy

    def initialize(the_policy, included_member_ids, opts = {})
      @policy = the_policy
      @included_member_ids = included_member_ids
      @options = opts
      @term_before_date = @options.fetch(:term_boundry) { nil }
      @member_repo = @options.fetch(:member_repo) { nil }
    end

    def serialize
      builder.to_xml(:indent => 2)
    end

    def builder(xml = Nokogiri::XML::Builder.new)
      xml['ins'].send(select_root_tag.to_sym, XMLNSES) do |xml|
        serialize_broker(xml)
        xml['ins'].exchange_policy_id(@policy.enrollment_group_id)
        serialize_subscriber(xml)
        serialize_members(xml)
        serialize_employer(xml)
        serialize_rp(xml)
        serialize_carrier(xml)
        serialize_plan(xml)
      end
      xml
    end

    def serialize_broker(xml)
      broker = @policy.broker
      if !broker.blank?
        xml['ins'].broker do |xml|
          xml['ins'].broker_name(broker.name_full)
          xml['ins'].broker_npn(broker.npn)
        end
      end
    end

    def serialize_rp(xml)
      if @policy.has_responsible_person?
        xml['ins'].responsible_person do |xml|
          serialize_contact(@policy.responsible_person, xml)
          xml['ins'].entity_identifier_code("Responsible Party")
        end
      end
    end

    def serialize_employer(xml)
      emp = employer_lookup(@policy)
      if !emp.nil?
        xml['emp'].employer do |xml|
          xml['emp'].name(emp.dba.blank?  ? emp.name : emp.dba)
          xml['emp'].exchange_employer_id(emp.hbx_id)
          xml['emp'].fein(emp.fein)
        end
      end
    end

    def serialize_subscriber(xml)
      subscriber = policy.enrollees.detect { |en| en.rel_code == "self" }
      if subscriber.present?
        if @included_member_ids.include?(subscriber.m_id)
          xml['ins'].subscriber do |xml|
            serialize_person(subscriber, xml)
          end
        end
      end
    end

    def serialize_members(xml)
      members = policy.enrollees.reject { |en| en.rel_code == "self" }
      members.each do |m|
        serialize_member(m, xml)
      end
    end

    def serialize_contact(person, xml)
      xml['con'].person do |xml|
        if !person.name_pfx.blank?
          xml['con'].name_prefix(person.name_pfx)
        end
        xml['con'].name_first(person.name_first.strip)
        if !person.name_middle.blank?
          xml['con'].name_middle(person.name_middle.strip)
        end
        xml['con'].name_last(person.name_last.strip)
        if !person.name_sfx.blank?
          xml['con'].name_suffix(person.name_sfx.strip)
        end
        if !person.home_phone.nil? && person.home_phone.phone_number != "0"
          xml['con'].phone do |xml|
            xml['con'].phone_type("home")
            xml['con'].phone_number(person.home_phone.phone_number)
          end
        end
        if !person.home_email.nil?
          xml['con'].email do |xml|
            xml['con'].email_type("home")
            xml['con'].email_address(person.home_email.email_address)
          end
        end
        serialize_address(person, xml)
      end
    end

    def serialize_person(en, xml)
      member = member_lookup(en)
      person = member.person
      serialize_contact(person, xml)
      xml['ins'].exchange_member_id(en.m_id)
      xml['ins'].individual_relationship_code(en.rel_code.titleize)
      if !member.dob.blank?
        xml['ins'].DOB(member.dob.strftime("%Y%m%d"))
      end
      if !member.ssn.blank?
        xml['ins'].SSN(member.ssn)
      end
      xml['ins'].gender_code(member.gender)
      xml['ins'].tobacco_use(person.authority_member.hlh)
      xml['ins'].coverage do |xml|
        xml['ins'].plan_id_ref(policy.plan_id)
        xml['ins'].premium_amount(en.pre_amt)
        if en.coverage_start.nil?
          raise @policy.inspect
        end
        xml['ins'].benefit_begin_date(en.coverage_start.strftime("%Y%m%d"))
        if should_show_end_date(en)
          xml['ins'].benefit_end_date(en.coverage_end.strftime("%Y%m%d"))
        end
      end
    end

    def should_show_end_date(en)
      if @term_before_date.nil?
        return(!en.coverage_end.blank? && !en.active?)
      end
      return(false) if en.coverage_end.blank?
      en.coverage_end <= @term_before_date
    end

    def determine_addresses_to_serialize(person)
      home_address = person.home_address
      mailing_address = person.addresses.detect { |adr| adr.address_type == "mailing" }
      if home_address.nil?
        if mailing_address.nil?
          []
        else
          [mailing_address]
        end
      else
        if mailing_address.nil?
          [home_address]
        else
          if home_address.same_location?(mailing_address)
            [home_address]
          else
            [home_address, mailing_address]
          end
        end
      end
    end

    def serialize_address(person, xml)
      given_addresses = determine_addresses_to_serialize(person)
      given_addresses.each do |addr|
        xml['con'].address do |xml|
          xml['con'].address_type(addr.address_type.strip)
          xml['con'].address do |xml|
            xml['bt'].address_1(addr.address_1.strip)
            if !addr.address_2.blank?
              xml['bt'].address_2(addr.address_2.strip)
            end
            xml['bt'].city(addr.city.strip)
            xml['bt'].state(addr.state.strip)
            xml['bt'].zipcode(addr.zip.strip)
          end
        end
      end
    end

    def serialize_member(member, xml)
      if @included_member_ids.include?(member.m_id)
        xml['ins'].member do |xml|
          serialize_person(member, xml)
        end
      end
    end

    def serialize_plan(xml)
      plan = plan_lookup(@policy)
      carrier = carrier_lookup(@policy)
      xml['ins'].plan do |xml|
        xml['pln'].plan do |xml|
          xml['pln'].carrier_id_ref(carrier._id)
          xml['pln'].hios_plan_id(plan.hios_plan_id)
          xml['pln'].plan_name(plan.name)
          xml['pln'].coverage_type(plan.coverage_type.capitalize)
        end
        xml['ins'].plan_id(plan._id)
        xml['ins'].premium_amount_total(@policy.pre_amt_tot)
        if @policy.employer_id.blank?
          xml['ins'].aptc_amount(@policy.applied_aptc)
        else
          xml['ins'].total_employer_responsibility_amount(@policy.tot_emp_res_amt)
        end
        xml['ins'].total_responsible_amount(@policy.tot_res_amt)
      end
    end

    def serialize_carrier(xml)
      carrier = carrier_lookup(policy)
      suffix = profile_suffix
      profile_name = "#{carrier.abbrev}_#{suffix}"
      xml['ins'].carrier do |xml|
        xml['car'].carrier do |xml|
          xml['car'].name(profile_name)
          xml['car'].display_name(carrier.name)
          xml['car'].exchange_carrier_id(carrier.hbx_carrier_id)
        end
        xml['ins'].carrier_id(carrier._id)
      end
    end

    def carrier_lookup(pol)
      Caches::MongoidCache.lookup(Carrier, pol.carrier_id) {
        pol.carrier
      }
    end

    def plan_lookup(pol)
      Caches::MongoidCache.lookup(Plan, pol.plan_id) {
        pol.plan
      }
    end

    def member_lookup(en)
      return en.member if @member_repo.nil?
      @member_repo.lookup(en.m_id)
    end

    def employer_lookup(pol)
      Caches::MongoidCache.lookup(Employer, pol.employer_id) {
        pol.employer
      }
    end

    def select_root_tag
      @policy.employer_id.blank? ? "individual_market_enrollment_group" : "shop_market_enrollment_group"
    end

    def profile_suffix
      @policy.employer_id.blank? ? "IND" : "SHP"
    end
  end
end
