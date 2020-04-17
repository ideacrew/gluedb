module EnrollmentAction
  module NotificationExemptionHelper

    def termination_event_exempt_from_notification?(policy, termination_date)
      return false if policy.is_shop?
      formated_date = format_string_to_date(termination_date)
      (formated_date.month == 12) && (formated_date.day == 31)
    end

    def format_string_to_date(date)
      if date.split('/').first.size == 2
        Date.strptime(date,"%m/%d/%Y")
      elsif date.split('-').first.size == 2
        Date.strptime(date,"%m-%d-%Y")
      end
    end
  end
end