module Generators
  class CoverageInformationSerializer
    include MoneyMath

    attr_accessor :policies, :person

    def initialize(person, plan_ids = nil)
      @person = person
      if plan_ids
        @policies = Policy.where({:enrollees => {"$elemMatch" => {:rel_code => "self",
                                                                  :m_id => person.authority_member_id}},
                                  :plan_id => {"$in" => plan_ids}})
      else
        @policies = person.policies
      end
    end

    def process
      policies.collect do |policy|
        @policy = policy
        {
          policy_id: policy._id.to_s,
          enrollment_group_id: policy.eg_id,
          qhp_id: policy.plan.hios_plan_id.split('-').first,
          allocated_aptc: policy.allocated_aptc.to_f,
          elected_aptc: policy.elected_aptc.to_f,
          applied_aptc: policy.applied_aptc.to_f,
          csr_amt: policy.csr_amt,
          total_premium_amount: policy.total_premium_amount.to_f,
          total_responsible_amount: policy.total_responsible_amount.to_f,
          coverage_start: format_date(policy.policy_start),
          coverage_end: format_date(policy.policy_end),
          coverage_kind: policy.kind,
          term_for_np: policy.term_for_np,
          rating_area: policy.rating_area,
          # need to figure out how service area should be pulled
          service_area: "",
          last_maintenance_date: policy.updated_at.to_date.strftime("%Y-%m-%d"),
          last_maintenance_time: policy.updated_at.strftime("%H%M%S%L"),
          aasm_state: policy.aasm_state,
          exchange_subscriber_id: policy.subscriber.m_id,
          effectuation_status: if policy.canceled?
                                 'N'
                               elsif policy.aasm_state == 'resubmitted'
                                 'Y'
                               else
                                 policy.effectuated? ? 'Y' : 'N'
                               end,
          insurance_line_code: (policy.plan.coverage_type =~ /health/i ? 'HLT' : 'DEN'),
          csr_variant: csr_variant,
          enrollees: transform_enrollees
        }
      end
    end

    def transform_enrollees
      @policy.enrollees.collect do |enrollee|
        person = enrollee.person
        {
          enrollee_demographics: construct_demograhic_info(enrollee),
          first_name: person.name_first,
          middle_name: person.name_middle,
          last_name: person.name_last,
          name_suffix: person.name_sfx,
          hbx_member_id: enrollee.m_id,
          premium_amount: enrollee.premium_amount.to_f,
          coverage_start: format_date(enrollee.coverage_start),
          coverage_end: format_date(enrollee.coverage_end),
          coverage_status: enrollee.coverage_status,
          relationship_status_code: enrollee.relationship_status_code,
          issuer_assigned_member_id: enrollee.carrier_member_id,
          issuer_assigned_policy_id: enrollee.carrier_policy_id,
          is_subscriber: enrollee.subscriber?,
          is_responsible_party: @policy.responsible_party.present? ? true : false,
          addresses: transform_addresses(enrollee.person.addresses),
          emails: transform_emails(enrollee.person.emails),
          phones: transform_phones(enrollee.person.phones),
          segments: construct_segments(enrollee).compact
        }
      end
    end

    def construct_demograhic_info(enrollee)
      member = enrollee.person.authority_member
      {
        dob: format_date(member.dob),
        ssn: member.ssn,
        gender_code: (member.gender == "male" ? 'M' : (member.gender == "female" ? 'F' : 'U')),
        tobacco_use_code: member.tobacco_use_code
      }
    end

    def construct_segments(enrollee)
      segments = []
      financial_dates = policy_history_dates

      financial_dates.each do |financial_dates|
        segments << append_financial_information(enrollee, financial_dates)
      end

      segments
    end

    def append_financial_information(enrollee, financial_dates=nil)
      start_date = financial_dates[0].strftime("%Y%m%d")
      subscriber_m_id = @policy.subscriber.m_id
      policy_id = @policy.eg_id
      enrollee_coverage_start = enrollee.coverage_start
      enrollee_coverage_end = enrollee.coverage_end.blank? ? @policy.policy_start.end_of_year : enrollee.coverage_end

      if (enrollee_coverage_start..enrollee_coverage_end).cover?(financial_dates[0])
        params = {
          id: "#{subscriber_m_id}-#{policy_id}-#{start_date}",
          effective_start_date: format_date(financial_dates[0]),
          effective_end_date: format_date(financial_dates[1]),
          individual_premium_amount: enrollee.premium_amount.to_f,
        }

        if enrollee.subscriber?
          aptc_credit = @policy.aptc_record_on(financial_dates[0])
          total_premium_amount = if aptc_credit.present?
                                   aptc_credit.pre_amt_tot.to_f
                                 else
                                   calculate_total_premium(financial_dates[0]).to_f
                                 end
          aptc_amount = if aptc_credit.present?
                          aptc_credit.aptc.to_f
                        else
                          ehb_amount = as_dollars(total_premium_amount * @policy.plan.ehb)
                          @policy.applied_aptc.to_f > ehb_amount.to_f ? ehb_amount : @policy.applied_aptc.to_f
                        end

          total_responsible_amount = if aptc_credit.present?
                                       aptc_credit.tot_res_amt.to_f
                                     else
                                       as_dollars((total_premium_amount - aptc_amount)).to_f
                                     end

          params.merge!({
                          total_premium_amount: total_premium_amount,
                          total_responsible_amount: total_responsible_amount,
                          aptc_amount: aptc_amount,
                          csr_variant: csr_variant
                        })
        end
        params
      end
    end

    def calculate_total_premium(date)
      premium_amount = 0.00
      @policy.enrollees.each do |enrollee|
        enrollee_coverage_start = enrollee.coverage_start
        enrollee_coverage_end = enrollee.coverage_end.blank? ? @policy.policy_start.end_of_year : enrollee.coverage_end
        if (enrollee_coverage_start..enrollee_coverage_end).cover?(date)
          premium_amount += as_dollars(enrollee.premium_amount)
        end
      end
      as_dollars(premium_amount)
    end

    def transform_addresses(addresses)
      return [] if addresses.blank?

      addresses.collect do |address|
        {
          kind: address.address_type,
          address_1: address.address_1,
          address_2: address.address_2,
          address_3: address.address_3,
          city: address.city,
          county: address.county,
          county_code: nil,
          state: address.state,
          zip: address.zip,
          country_name: address.country_name
        }
      end
    end

    def transform_emails(emails)
      return [] if emails.blank?

      emails.collect do |email|
        {
          kind: email.email_type,
          address: email.email_address
        }
      end
    end

    def transform_phones(phones)
      return [] if phones.blank?

      phones.collect do |phone|
        {
          kind: phone.phone_type,
          phone_type: phone.country_code,
          area_code: phone.phone_number.slice(0..2),
          number: phone.phone_number.slice(3..10),
          extension: phone.extension,
          primary: phone.primary,
          full_phone_number: phone.phone_number
        }
      end
    end

    def csr_variant
      if @policy.plan.coverage_type =~ /health/i
        @policy.plan.hios_plan_id.split('-').last
      else
        '01'
      end
    end

    def add_loop_start_date(loop_start_dates, loop_start)
      loop_start_dates << loop_start if within_policy_period?(loop_start)
      loop_start_dates
    end

    def within_policy_period?(loop_start)
      policy_end_date = @policy.policy_end
      policy_end_date = @policy.policy_start.end_of_year if policy_end_date.blank?
      (@policy.policy_start..policy_end_date).cover?(loop_start)
    end

    def policy_history_dates
      active_enrollees = @policy.enrollees.reject { |e| e.canceled?}
      loop_start_dates = [@policy.policy_start]

      # Incorporate Enrollee Start and End Dates
      active_enrollees.each do |enrollee|
        if enrollee.coverage_start != @policy.policy_start
          loop_start_dates = add_loop_start_date(loop_start_dates, enrollee.coverage_start)
        end

        if enrollee.coverage_end.present? && (enrollee.coverage_end != @policy.policy_end)
          loop_start_dates = add_loop_start_date(loop_start_dates, enrollee.coverage_end.next_day)
        end
      end

      # Incorporate APTC Credits Start and End Dates
      # aptc_credits.start_on and aptc_credits.end_on are mandatory fields - presence check not required for end_on date
      @policy.aptc_credits.each do |credit|
        if credit.start_on != @policy.policy_start
          loop_start_dates = add_loop_start_date(loop_start_dates, credit.start_on)
        end

        if credit.end_on != @policy.policy_end
          loop_start_dates = add_loop_start_date(loop_start_dates, credit.end_on.next_day)
        end
      end

      loop_start_dates = loop_start_dates.uniq.sort
      loop_start_dates.inject([]) do |loops, start_date|
        next_start_date = loop_start_dates.index(start_date) + 1
        end_date = loop_start_dates[next_start_date].prev_day if loop_start_dates[next_start_date].present?
        loops << [start_date, (end_date || @policy.policy_end)]
      end
    end

    def format_date(date)
      date = @policy.policy_start.end_of_year if date.blank?
      date.strftime("%Y-%m-%d")
    end
  end
end
