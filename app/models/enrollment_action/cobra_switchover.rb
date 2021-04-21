module EnrollmentAction
  class CobraSwitchover < Base
    extend ReinstatementComparisonHelper
    extend PlanComparisonHelper

    def self.qualifies?(chunk)
      return false if chunk.length < 2
      return false unless chunk.first.is_termination?
      return false unless chunk.last.is_cobra?
      return false if chunk.last.is_termination?
      return false if carriers_are_different?(chunk)
      start_and_end_dates_align(chunk)
    end

    def persist
      ep = ExternalEvents::ExternalPolicyCobraSwitch.new(action.policy_cv, termination.existing_policy)
      ep.persist
    end

    def publish
      existing_policy = termination.existing_policy
      term_connection = termination.event_responder.connection
      term_helper = ActionPublishHelper.new(termination.event_xml)
      member_date_map = {}
      existing_policy.enrollees.each do |en|
        member_date_map[en.m_id] = en.coverage_start
        if en.c_id.present? || en.cp_id.present?
          term_helper.set_member_level_carrier_assigned_ids(en)
          term_helper.set_policy_level_carrier_assigned_ids(en)
        end
      end
      term_helper.set_event_action("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
      term_helper.set_policy_id(existing_policy.eg_id)
      term_helper.set_member_starts(member_date_map)
      publish_result, publish_errors = publish_edi(term_connection, term_helper.to_xml, termination.hbx_enrollment_id, termination.employer_hbx_id)
      unless publish_result
        return [publish_result, publish_errors]
      end
      amqp_connection = action.event_responder.connection
      action_helper = EnrollmentAction::ActionPublishHelper.new(action.event_xml)
      action_helper.set_event_action("urn:openhbx:terms:v1:enrollment#reinstate_enrollment")
      action_helper.keep_member_ends([])
      action_helper.set_member_starts(member_date_map)
      action_helper.set_policy_id(existing_policy.eg_id)
      publish_edi(amqp_connection, action_helper.to_xml, action.hbx_enrollment_id, action.employer_hbx_id)
    end
  end
end
