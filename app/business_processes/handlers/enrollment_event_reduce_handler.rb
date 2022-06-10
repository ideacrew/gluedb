module Handlers
  class EnrollmentEventReduceHandler < Base
    
    # call :: [::ExternalEvents::EnrollmentEventNotification]-> [[::ExternalEvents::EnrollmentEventNotification]]
    # We split out and collate the events into buckets.  Then we call the step after us once for each bucket.
    def call(context)
      no_dupe_events = discard_already_processed_events(context)
      processable_terms = discard_term_event_if_term_processed_by_carrier(no_dupe_events)
      no_bad_terms = discard_terms_with_no_end_date(processable_terms)
      no_rerun_terms = discard_already_processed_terminations(no_bad_terms)
      reduced_list = perform_reduction(no_rerun_terms)
      reduced_list.map do |element|
#        begin
          super(element)
#        rescue
          # Add error information to duplicated context
#        end
      end
    end

    protected

    def discard_already_processed_terminations(enrollments)
      filter = ::ExternalEvents::EnrollmentEventNotificationFilters::AlreadyProcessedTermination.new
      filter.filter(enrollments)
    end

    def discard_term_event_if_term_processed_by_carrier(enrollments)
      filter = ::ExternalEvents::EnrollmentEventNotificationFilters::TerminationAlreadyProcessedByCarrier.new
      filter.filter(enrollments)
    end

    def discard_already_processed_events(enrollments)
      filter = ::ExternalEvents::EnrollmentEventNotificationFilters::AlreadyProcessedEvent.new
      filter.filter(enrollments)
    end

    def discard_terms_with_no_end_date(enrollments)
      filter = ::ExternalEvents::EnrollmentEventNotificationFilters::TerminationWithoutEnd.new
      filter.filter(enrollments)
    end

    def perform_reduction(full_event_list)
      duplicate_filter = ::ExternalEvents::EnrollmentEventNotificationFilters::RemoveSameActionsAndSelectSilent.new
      event_list = duplicate_filter.filter(full_event_list)
      event_list.combination(2).each do |a, b|
        if a.hash == b.hash
          a.check_and_mark_duplication_against(b)
        end
      end
      dropped, free_of_dupes  = event_list.partition(&:drop_if_marked!)
      # GC hint
      dropped = nil
      free_of_dupes.group_by(&:bucket_id).values
    end
  end
end
