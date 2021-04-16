module EnrollmentAction
  class AssistanceChange < Base
    extend PlanComparisonHelper
    extend DependentComparisonHelper
    extend AssistanceComparisonHelper

    def self.qualifies?(chunk)
      return false unless chunk.length > 1
      return false unless same_plan?(chunk)
      return false if dependents_changed?(chunk)
      return false if chunk.first.is_shop?
      aptc_changed?(chunk)
    end

    # persist: update the aptc and premium amounts
    #          and add an enrollment id
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

    # publish: here we need to:
    #          - add effective date of aptc
    #          - change the start dates to that of the original policy
    #          - change the event type to change_financial_assistance
    #          The xml we will use comes from the second event, and we alter that.
    def publish
      amqp_connection = action.event_responder.connection
      policy_to_change = termination.existing_policy
      subscriber_start = action.subscriber_start
      member_date_map = {}
      action_helper = EnrollmentAction::ActionPublishHelper.new(action.event_xml)
      policy_to_change.enrollees.each do |en|
        member_date_map[en.m_id] = en.coverage_start
        action_helper.set_carrier_member_id("urn:openhbx:hbx:me0:resources:v1:person:member_id##{en.c_id}") if en.c_id.present?
        action_helper.set_carrier_policy_id("urn:openhbx:hbx:me0:resources:v1:person:policy_id##{en.cp_id}") if en.cp_id.present?
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
