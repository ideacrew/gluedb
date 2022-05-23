module EnrollmentAction
  class RetroAssistanceChangeToActive < Base
    extend PlanComparisonHelper
    extend DependentComparisonHelper
    extend AssistanceComparisonHelper

    def self.qualifies_3?(chunk)
      qualifies?(chunk)
    end

    def self.qualifies?(chunk)
      #[retro term/cancel, current cancel, retro assistance change]
      return false if chunk.length < 3
      return false if chunk.first.is_shop?
      return false unless same_plan?([chunk.first, chunk.last])
      return false if dependents_changed?([chunk.first, chunk.last])
      chunk.second.is_cancel? && aptc_changed?([chunk.first, chunk.last])
    end

    def persist
      policy = termination.existing_policy
      policy.hbx_enrollment_ids << action.hbx_enrollment_id
      policy.save!
      policy_updater = ExternalEvents::ExternalPolicyAssistanceChange.new(
        policy,
        action
      )
      policy_updater.persist
    end

    def publish
      amqp_connection = action.event_responder.connection
      policy_to_change = termination.existing_policy
      subscriber_start = action.subscriber_start
      member_date_map = {}
      action_helper = EnrollmentAction::ActionPublishHelper.new(action.event_xml)
      policy_to_change.enrollees.each do |en|
        member_date_map[en.m_id] = en.coverage_start
        if en.c_id.present? || en.cp_id.present?
          action_helper.set_carrier_assigned_ids(en)
        end
      end
      action_helper.set_event_action("urn:openhbx:terms:v1:enrollment#change_financial_assistance")
      action_helper.set_policy_id(policy_to_change.eg_id)
      action_helper.set_member_starts(member_date_map)
      action_helper.keep_member_ends([])
      action_helper.assign_assistance_date(subscriber_start)
      publish_edi(amqp_connection, action_helper.to_xml, action.hbx_enrollment_id, action.employer_hbx_id)
    end
  end
end
