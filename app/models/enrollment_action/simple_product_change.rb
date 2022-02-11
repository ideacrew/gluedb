module EnrollmentAction
  class SimpleProductChange < Base
    extend PlanComparisonHelper
    extend DependentComparisonHelper
    include TerminationDateHelper

    def self.qualifies?(chunk)
      return false if chunk.length < 2
      return false if same_plan?(chunk)
      return false if carriers_are_different?(chunk)
      return false if carrier_requires_term_drop?(chunk)
      carrier_requires_simple_plan_changes?(chunk)
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
      ep = ExternalEvents::ExternalPolicy.new(action.policy_cv, action.existing_plan, action.is_cobra?)
      return false unless ep.persist
      policy_to_term = termination.existing_policy
      policy_to_term.terminate_as_of(select_termination_date)
    end

    def publish
      amqp_connection = termination.event_responder.connection
      existing_policy = termination.existing_policy
      member_date_map = {}
      member_end_date_map = {}
      termination_helper = ActionPublishHelper.new(termination.event_xml)
      existing_policy.enrollees.each do |en|
        member_date_map[en.m_id] = en.coverage_start
        member_end_date_map[en.m_id] = en.coverage_end
        if en.c_id.present? || en.cp_id.present?
          termination_helper.set_carrier_assigned_ids(en)
        end
      end
      termination_helper.set_event_action("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
      termination_helper.set_policy_id(existing_policy.eg_id)
      termination_helper.set_member_starts(member_date_map)
      termination_helper.set_member_end_date(member_end_date_map)
      termination_helper.swap_qualifying_event(action.event_xml)
      publish_result, publish_errors = publish_edi(amqp_connection, termination_helper.to_xml, existing_policy.eg_id, termination.employer_hbx_id)
      unless publish_result
        return [publish_result, publish_errors]
      end
      action_helper = EnrollmentAction::ActionPublishHelper.new(action.event_xml)
      action_helper.set_event_action("urn:openhbx:terms:v1:enrollment#change_product")
      action_helper.keep_member_ends([])
      existing_policy.enrollees.each do |en|
        if en.c_id.present?
          action_helper.set_carrier_assigned_ids(en, false)
        end
      end
      publish_edi(amqp_connection, action_helper.to_xml, action.hbx_enrollment_id, action.employer_hbx_id)
    end
  end
end
