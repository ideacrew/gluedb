module EnrollmentAction
  class CarefirstTermination < Base
    extend ReinstatementComparisonHelper
    
    def self.qualifies?(chunk)
      return false if chunk.length > 1
      return false if reinstate_capable_carrier?(chunk.first)
      chunk.first.is_termination?
    end

    # Remember, we only have an @terminate_enrollmenttion, no @action item
    def persist
      if termination.existing_policy
        policy_to_term = termination.existing_policy
        policy_to_term.reload
        unless policy_to_term.is_shop?
          # last span id should result in policy termination
          return false if policy_to_term.hbx_enrollment_ids.sort.last.to_s != termination.hbx_enrollment_id.to_s
          # reterm of policy should be handled by different action
          return false if (policy_to_term.terminated? || policy_to_term.canceled?)
        end
        # Is this even a cancellation, if so, check for custom NPT behaviour,
        # otherwise do nothing

        if termination.is_cancel?
          begin
            canceled_policy_m_id = policy_to_term.subscriber.m_id
            canceled_policy_plan_id = policy_to_term.plan_id
            canceled_policy_carrier_id = policy_to_term.carrier_id
            canceled_policy_test_date = (policy_to_term.policy_start - 1.day)
            pols = Person.where(authority_member_id: canceled_policy_m_id ).first.policies
            pols.each do |pol|
              if (pol.aasm_state == "terminated" && pol.employer_id == nil)
                if (pol.policy_end == canceled_policy_test_date && pol.plan_id == canceled_policy_plan_id && pol.carrier_id == canceled_policy_carrier_id)
                  unless pol.versions.empty?
                    last_version_npt = pol.versions.last.term_for_np
                    pol.update_attributes!(term_for_np: last_version_npt)
                  end
                end
              end
            end
          rescue Exception => e
            puts e.to_s
          end
        end
        if termination.is_cancel? && termination.subscriber_start != policy_to_term.policy_start
          policy_to_term.terminate_as_of(termination.subscriber_end - 1.day)
        else
          policy_to_term.terminate_as_of(termination.subscriber_end)
        end
        if termination.existing_policy.carrier.termination_cancels_renewal
          termination.renewal_policies_to_cancel.each do |pol|
            pol.cancel_via_hbx!
          end
        end
        true
      else
        false
      end
    end

    def publish
      existing_policy = termination.existing_policy
      member_date_map = {}
      member_end_date_map = {}
      action_helper = ActionPublishHelper.new(termination.event_xml)
      existing_policy.enrollees.each do |en|
        member_date_map[en.m_id] = en.coverage_start
        member_end_date_map[en.m_id] = en.coverage_end
        if en.c_id.present? || en.cp_id.present?
          action_helper.set_carrier_assigned_ids(en)
        end
      end
      action_helper.set_event_action("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
      action_helper.set_policy_id(existing_policy.eg_id)
      action_helper.set_member_starts(member_date_map)
      action_helper.set_member_end_date(member_end_date_map)
      amqp_connection = termination.event_responder.connection
      publish_edi(amqp_connection, action_helper.to_xml, termination.hbx_enrollment_id, termination.employer_hbx_id)
    end
  end
end
