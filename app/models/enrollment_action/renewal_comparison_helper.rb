module EnrollmentAction
  module RenewalComparisonHelper
    include Handlers::EnrollmentEventXmlHelper

    def any_renewal_candidates?(enrollment_event)
      (same_carrier_renewal_candidates(enrollment_event).any? ||
        other_carrier_renewal_candidates(enrollment_event).any?)
    end

    def carrier_requires_simple_renewal?(enrollment_event)
      plan = extract_plan(enrollment_event.policy_cv)
      plan.carrier.requires_simple_renewal?
    end
    
    def same_carrier_renewal_candidates(enrollment_event)
      if enrollment_event.is_shop?
        shop_renewal_candidates(enrollment_event.policy_cv, true)
      else
        plan, subscriber_person, subscriber_id, subscriber_start = extract_ivl_policy_details(enrollment_event.policy_cv)
        return [] if subscriber_person.nil?
        subscriber_person.policies.select do |pol|
          ivl_renewal_candidate?(pol, plan, subscriber_id, subscriber_start, true)
        end
      end
    end

    def other_carrier_renewal_candidates(enrollment_event)
      if enrollment_event.is_shop?
        shop_renewal_candidates(enrollment_event.policy_cv, false)
      else
        plan, subscriber_person, subscriber_id, subscriber_start = extract_ivl_policy_details(enrollment_event.policy_cv)
        return [] if subscriber_person.nil?
        subscriber_person.policies.select do |pol|
          ivl_renewal_candidate?(pol, plan, subscriber_id, subscriber_start, false)
        end
      end
    end

    def renewal_dependents_changed?(renewal_candidate, enrollment_event)
      renewal_dependents_added?(renewal_candidate, enrollment_event) ||
        renewal_dependents_dropped?(renewal_candidate, enrollment_event)
    end

    def renewal_dependents_added?(renewal_candidate, enrollment_event)
      renewal_members = renewal_candidate.active_member_ids
      (enrollment_event.all_member_ids - renewal_members).any?
    end

    def renewal_dependents_dropped?(renewal_candidate, enrollment_event)
      renewal_members = renewal_candidate.active_member_ids
      (renewal_members - enrollment_event.all_member_ids).any?
    end

    def ivl_renewal_candidate?(pol, plan, subscriber_id, subscriber_start, same_carrier)
      return false if pol.is_shop?
      return false if (pol.subscriber.m_id != subscriber_id)
      return false unless (pol.plan.year == plan.year - 1)
      return false unless (plan.coverage_type == pol.plan.coverage_type)
      return false if pol.canceled?
      return false if pol.terminated?
      if same_carrier
        return false unless (plan.carrier_id == pol.plan.carrier_id) 
      else
        return false if (plan.carrier_id == pol.plan.carrier_id) 
      end
      (pol.coverage_period.end == (subscriber_start - 1.day))
    end

    def shop_renewal_candidates(policy_cv, same_carrier)
      subscriber_enrollee = extract_subscriber(policy_cv)
      subscriber_start = extract_enrollee_start(subscriber_enrollee)
      subscriber_id = extract_member_id(subscriber_enrollee)
      subscriber_person = Person.find_by_member_id(subscriber_id)
      employer = find_employer(policy_cv)
      plan_year = find_employer_plan_year(policy_cv)
      return [] if subscriber_person.nil?
      subscriber_end = extract_enrollee_end(subscriber_enrollee)
      if subscriber_end.blank?
        subscriber_end = plan_year.end_date
      end
      plan = extract_plan(policy_cv)
      subscriber_person.policies.select do |pol|
        shop_renewal_candidate?(pol, plan, employer, subscriber_id, subscriber_start, same_carrier)
      end
    end

    def shop_renewal_candidate?(pol, plan, employer, subscriber_id, subscriber_start, same_carrier)
      return false if pol.employer_id.blank?
      return false if pol.canceled?
      return false if pol.terminated?
      return false if pol.subscriber.blank?
      return false if (pol.subscriber.m_id != subscriber_id)
      return false unless (plan.coverage_type == pol.plan.coverage_type)
      return false unless (pol.employer_id == employer.id)
      return false unless (plan.year == pol.plan.year + 1)
      if same_carrier
        return false unless (plan.carrier_id == pol.plan.carrier_id) 
      else
        return false if (plan.carrier_id == pol.plan.carrier_id) 
      end
      pol.coverage_period.end == subscriber_start - 1.day
    end

    def extract_ivl_policy_details(policy_cv)
          subscriber_enrollee = extract_subscriber(policy_cv)
          subscriber_id = extract_member_id(subscriber_enrollee)
          subscriber_start = extract_enrollee_start(subscriber_enrollee)
          plan = extract_plan(policy_cv)
          coverage_type = plan.coverage_type
          subscriber_person = Person.find_by_member_id(subscriber_id)
          [plan, subscriber_person, subscriber_id, subscriber_start]
    end

    def has_prev_coverage(e_event)
      subscriber_person = Person.find_by_member_id(e_event.subscriber_id)
      employer = find_employer(e_event.policy_cv)
      return false unless subscriber_person
      subscriber_person.policies.select do |pol|
        has_active_coverage_for?(pol, e_event.existing_plan, e_event.subscriber_id, e_event.subscriber_start, employer)
      end
    end

    def has_active_coverage_for?(pol, plan, subscriber_id, subscriber_start, employer)
      if pol.is_shop?
        return false if pol.employer_id.blank?
        return false if employer.blank?
        return false unless pol.employer_id == employer.id
      end
      return false if (pol.subscriber.m_id != subscriber_id)
      return false unless (pol.plan.year == plan.year)
      return false unless (plan.coverage_type == pol.plan.coverage_type)
      return false if pol.canceled?
      return false if pol.terminated?
      return false unless (plan.carrier_id == pol.plan.carrier_id)
      pol.coverage_period.include?(subscriber_start)
    end

    def continued_coverage_renewal_candidates?(retro_candidate, renewal_candidate)
      return false if has_prev_coverage(retro_candidate).present?
      retro_plan = retro_candidate.existing_plan
      renewal_plan = renewal_candidate.existing_plan
      return false unless retro_plan
      return false unless renewal_plan
      return false unless retro_plan.carrier_id == renewal_plan.carrier_id
      return false unless retro_plan.coverage_type == renewal_plan.coverage_type
      return unless retro_candidate.plan_matched?(retro_plan, renewal_plan)
      return if (retro_candidate.all_member_ids - renewal_candidate.all_member_ids).any?
      return if (renewal_candidate.all_member_ids - retro_candidate.all_member_ids).any?
      renewal_candidate.subscriber_start == retro_candidate.coverage_year.end + 1.day
    end
  end
end
