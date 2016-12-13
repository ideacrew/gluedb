module Handlers
  module EnrollmentEventXmlHelper
    def extract_subscriber(policy_cv)
      policy_cv.enrollees.detect { |en| en.subscriber? }
    end

    def extract_member_id(enrollee)
      Maybe.new(enrollee).member.id.strip.split("#").last.value
    end

    def extract_enrollee_start(enrollee)
      val = Maybe.new(enrollee).benefit.begin_date.strip.value
      return nil if val.blank?
      Date.strptime(val, "%Y%m%d")
    end

    def extract_enrollee_end(enrollee)
      val = Maybe.new(enrollee).benefit.end_date.strip.value
      return nil if val.blank?
      Date.strptime(val, "%Y%m%d")
    end

    def extract_enrollment_group_id(policy_cv)
      Maybe.new(policy_cv).id.strip.split("#").last.value
    end

    def extract_policy(enrollment_event_cv)
      Maybe.new(enrollment_event_cv).event.body.enrollment.policy.value
    end

    def enrollment_event_cv_for(event_xml)
      Openhbx::Cv2::EnrollmentEvent.parse(event_xml, :single => true)
    end

    def extract_hios_id(policy_cv)
      return nil if policy_cv.policy_enrollment.plan.id.blank?
      policy_cv.policy_enrollment.plan.id.split("#").last
    end

    def extract_active_year(policy_cv)
      return nil if policy_cv.policy_enrollment.plan.blank?
      policy_cv.policy_enrollment.plan.active_year
    end

    def extract_plan(policy_cv)
      hios_id = extract_hios_id(policy_cv)
      active_year = extract_active_year(policy_cv)
      Plan.where(:hios_plan_id => hios_id, :year => active_year.to_i).first
    end

    def determine_market(enrollment_event_cv)
      shop_enrollment = Maybe.new(enrollment_event_cv).event.body.enrollment.policy.policy_enrollment.shop_market.value
      shop_enrollment.nil? ? "individual" : "shop"
    end

    def extract_employer_link(policy_cv)
      shop_enrollment = Maybe.new(policy_cv).policy_enrollment.shop_market.value
      Maybe.new(shop_enrollment).employer_link.value
    end

    def extract_shop_enrollment(policy_cv)
      Maybe.new(policy_cv).policy_enrollment.shop_market.value
    end

    def find_employer_plan_year(policy_cv)
      employer = find_employer(policy_cv)
      subscriber_enrollee = extract_subscriber(policy_cv)
      subscriber_start = extract_enrollee_start(subscriber_enrollee)
      employer.plan_year_of(subscriber_start)
    end

    def find_employer(policy_cv)
      employer_link = extract_employer_link(policy_cv)
      employer_fein = Maybe.new(employer_link).id.strip.split("#").last.value
      return nil if employer_fein.blank?
      Employer.where(fein: employer_fein).first
    end
  end
end
