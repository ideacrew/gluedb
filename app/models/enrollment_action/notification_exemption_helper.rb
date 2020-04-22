module EnrollmentAction
  module NotificationExemptionHelper

    def termination_event_exempt_from_notification?(policy, termination_date)
      return false if policy.is_shop?
      formated_date = format_string_to_date(termination_date)
      (formated_date.month == 12) && (formated_date.day == 31) && check_for_npt_flag_end_date(policy)
    end

    def format_string_to_date(date)
      return date if date.class == Date
      if date.split('/').first.size == 2
        Date.strptime(date,"%m/%d/%Y")
      elsif date.split('-').first.size == 2
        Date.strptime(date,"%m-%d-%Y")
      end
    end

    def check_for_npt_flag_end_date(policy)
      #new policy will not have prior versions
      if policy.versions.present?
        before_updated_policy = policy.versions.order_by(updated_at: :desc).first
        before_updated_policy.policy_end.nil? && (policy.term_for_np == before_updated_policy.term_for_np)
      else
        false
      end
    end
  end
end