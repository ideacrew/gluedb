module EnrollmentAction
  module NotificationExemptionHelper
    def termination_event_exempt_from_notification?(policy, termination_date)
      return false if policy.is_shop?
      (termination_date.month == 12) && (termination_date.day == 31)
    end
  end
end