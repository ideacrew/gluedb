module Generators
  class CoverageInformationSerializer
    include MoneyMath

    attr_accessor :policies, :person

=begin
    def initialize(person, plan)
      @person = person
      @policies = person.policies.where(plan_id: plan._id)
    end
=end

    def initialize(person, filter_to_plans = nil)
      @person = person
      if filter_to_plans
        filter_ids = filter_to_plans.map(&:_id)
        @policies = person.policies.select do |pol|
          filter_ids.include?(pol.plan_id)
        end
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
          total_responsible_amt: policy.total_responsible_amount.to_f,
          coverage_start: format_date(policy.policy_start),
          coverage_end: format_date(policy.policy_end),
          coverage_kind: policy.kind,
          term_for_np: policy.term_for_np,
          rating_area: policy.rating_area,
          service_area: "",
          last_maintenance_date: policy.updated_at.to_date.strftime("%Y-%m-%d"),
          last_maintenance_time: policy.updated_at.to_date.to_time.strftime("%H:%M:%S"),
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
          issuer_assigned_policy_id: enrollee.cp_id,
          is_subscriber: enrollee.subscriber?,
          is_responsible_party: @policy.responsible_party.present? ? true : false,
          addresses: transform_addresses(enrollee.person.addresses),
          emails: transform_emails(enrollee.person.emails),
          phones: transform_phones(enrollee.person.phones),
          segments: construct_segments(enrollee)
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
      if enrollee.subscriber?
        financial_dates = policy_history_dates
        financial_dates.each do |financial_dates|
          segments << append_financial_information(enrollee, financial_dates)
        end
      else
        segments << append_financial_information(enrollee)
      end
      segments
    end

    def append_financial_information(enrollee, financial_dates=nil)
      if financial_dates.present?
        start_date = financial_dates[0].strftime("%Y%m%d")
        end_date = financial_dates[1].blank? ? @policy.policy_start.end_of_year.strftime("%Y%m%d")
                     : financial_dates[1].strftime("%Y%m%d")
        @policy_disposition = PolicyDisposition.new(@policy)
        {
          id: "#{@policy.subscriber.m_id}-#{@policy._id}-#{@policy.subscriber.m_id}-#{start_date}-#{end_date}",
          effective_start_date: format_date(financial_dates[0]),
          effective_end_date: format_date(financial_dates[1]),
          individual_premium_amount: enrollee.premium_amount.to_f,
          total_premiumum_amount: @policy_disposition.as_of(financial_dates[0]).pre_amt_tot.to_f,
          total_responsible_amount: @policy_disposition.as_of(financial_dates[0]).tot_res_amt.to_f,
          aptc_amount: @policy_disposition.as_of(financial_dates[0]).applied_aptc.to_f,
          csr_variant: csr_variant
        }
      else
        start_date = enrollee.coverage_start.strftime("%Y%m%d")
        end_date = enrollee.coverage_end.blank? ? @policy.policy_start.end_of_year.strftime("%Y%m%d")
                     : enrollee.coverage_end.strftime("%Y%m%d")
        {
          id: "#{@policy.subscriber.m_id}-#{@policy._id}-#{enrollee.m_id}-#{start_date}-#{end_date}",
          effective_start_date: format_date(enrollee.coverage_start),
          effective_end_date: format_date(enrollee.coverage_end),
          individual_premium_amount: enrollee.premium_amount,
        }
      end
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
