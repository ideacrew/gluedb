module ExternalEvents
  module EnrollmentEventNotificationFilters
    class RemoveSameActionsAndSelectSilent
      def filter(full_event_list)
        full_event_list.inject([]) do |acc, event|
          duplicate_found = acc.detect do |item|
            [event.hbx_enrollment_id, event_comparison_action(event.enrollment_action)] == [item.hbx_enrollment_id, event_comparison_action(item.enrollment_action)]
          end
          # Favor the event marked as silent in the case of terminations
          if duplicate_found && event.is_termination?
            if (!duplicate_found.is_publishable?)
              event.drop_payload_duplicate!
              acc
            elsif (!event.is_publishable?)
              # Fix to favor earlier dates with multiple terminations
              filtered_accs = acc.reject do |item|
                [event.hbx_enrollment_id, event_comparison_action(event.enrollment_action)] == [item.hbx_enrollment_id, event_comparison_action(item.enrollment_action)]
              end
              duplicate_found.drop_payload_duplicate!
              filtered_accs + [event]
            else
              event.drop_payload_duplicate!
              acc
            end
          # In the case of initials, favor the event marked as auto_renewal if it exists
          elsif duplicate_found && event.is_coverage_starter?
            if (duplicate_found.is_passive_renewal?)
              event.drop_payload_duplicate!
              acc
            elsif (event.is_passive_renewal?)
              filtered_accs = acc.reject do |item|
                [event.hbx_enrollment_id, event_comparison_action(event.enrollment_action)] == [item.hbx_enrollment_id, event_comparison_action(item.enrollment_action)]
              end
              duplicate_found.drop_payload_duplicate!
              filtered_accs + [event]
            else
              event.drop_payload_duplicate!
              acc
            end
          else
            acc + [event]
          end
        end
      end

      def event_comparison_action(event_action)
        events_counting_as_coverage_selected = ExternalEvents::EnrollmentEventNotification::COVERAGE_START_EVENTS
        return "urn:openhbx:terms:v1:enrollment#initial" if events_counting_as_coverage_selected.include?(event_action)
        event_action
      end
    end
  end
end
