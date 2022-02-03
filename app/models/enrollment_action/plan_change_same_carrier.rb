module EnrollmentAction
  class PlanChangeSameCarrier < Base
    extend PlanComparisonHelper
    include NotificationExemptionHelper
    include RenewalComparisonHelper
    include TerminationDateHelper

    def self.qualifies?(chunk)
      return false unless chunk.length > 1
      return false if carriers_are_different?(chunk)
      return false if same_plan?(chunk)
      carrier_requires_term_drop?(chunk)
    end

    def persist
      return false if check_already_exists
      members = action.policy_cv.enrollees.map(&:member)
      members_persisted = members.map do |mem|
        em = ExternalEvents::ExternalMember.new(mem)
        em.persist
      end
      unless members_persisted.all?
        return false
      end
      ep = ExternalEvents::ExternalPolicy.new(action.policy_cv, action.existing_plan, action.is_cobra?, market_from_payload: action.kind)
      return false unless ep.persist
      policy_to_term = termination.existing_policy
      existing_npt = policy_to_term.term_for_np
      result = policy_to_term.terminate_as_of(select_termination_date)
      if termination.existing_policy.carrier.termination_cancels_renewal
        termination.renewal_policies_to_cancel.each do |pol|
          pol.cancel_via_hbx!
        end
      end
      unless termination_event_exempt_from_notification?(policy_to_term, termination.subscriber_end, true, existing_npt)
        Observers::PolicyUpdated.notify(policy_to_term)
      end
      result
    end

    def publish
      amqp_connection = termination.event_responder.connection
      action_helper = EnrollmentAction::ActionPublishHelper.new(action.event_xml)

      existing_policy = termination.existing_policy
      member_date_map = {}
      existing_policy.enrollees.each do |en|
        member_date_map[en.m_id] = en.coverage_start
      end
      termination_helper = ActionPublishHelper.new(termination.event_xml)
      termination_helper.set_event_action("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
      termination_helper.set_policy_id(existing_policy.eg_id)
      termination_helper.set_member_starts(member_date_map)
      termination_helper.swap_qualifying_event(action.event_xml)
      existing_policy.enrollees.each do |en|
        termination_helper.set_carrier_assigned_ids(en)
        action_helper.set_carrier_assigned_ids(en, false)
      end
      publish_result, publish_errors = publish_edi(amqp_connection, termination_helper.to_xml, existing_policy.eg_id, termination.employer_hbx_id)
      unless publish_result
        return [publish_result, publish_errors]
      end
      action_helper.set_event_action("urn:openhbx:terms:v1:enrollment#initial")

      action_helper.keep_member_ends([])
      publish_edi(amqp_connection, action_helper.to_xml, action.hbx_enrollment_id, action.employer_hbx_id)
    end
  end
end
