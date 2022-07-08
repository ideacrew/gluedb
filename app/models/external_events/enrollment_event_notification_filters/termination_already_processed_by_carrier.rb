module ExternalEvents
  module EnrollmentEventNotificationFilters
    class TerminationAlreadyProcessedByCarrier
      def filter(enrollments)
        enrollments.reject do |en|
          en.drop_term_event_if_term_processed_by_carrier!
        end
      end
    end
  end
end
