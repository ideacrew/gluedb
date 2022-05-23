module EnrollmentAction
  class RetroDependentDropToActive < Base
    extend PlanComparisonHelper
    extend DependentComparisonHelper
    include TerminationDateHelper

    def self.qualifies_3?(chunk)
      qualifies?(chunk)
    end

    def self.qualifies?(chunk)
      #[retro term/cancel, current cancel, retro drop]
      return false if chunk.length < 3
      return false if chunk.first.is_shop?
      return false unless same_plan?([chunk.first, chunk.last])
      chunk.second.is_cancel? && dependents_dropped?([chunk.first, chunk.last])
    end

    def persist
      policy_to_change = termination.existing_policy
      return false unless policy_to_change
      policy_to_change.hbx_enrollment_ids << action.hbx_enrollment_id
      policy_to_change.save
      pol_updater = ExternalEvents::ExternalPolicyMemberDrop.new(policy_to_change, termination.policy_cv, dropped_dependents)
      pol_updater.use_totals_from(action.policy_cv)
      pol_updater.subscriber_start(action.subscriber_start)
      pol_updater.member_drop_date(select_termination_date)
      pol_updater.persist
      true
    end

    def dropped_dependents
      termination.all_member_ids - action.all_member_ids
    end

    def publish
      amqp_connection = termination.event_responder.connection
      existing_policy = termination.existing_policy
      existing_policy.reload
      termination_helper = ActionPublishHelper.new(termination.event_xml)
      member_date_map = {}
      member_end_date_map = {}
      existing_policy.enrollees.each do |en|
        member_date_map[en.m_id] = en.coverage_start
        member_end_date_map[en.m_id] = en.coverage_end
        if en.c_id.present? || en.cp_id.present?
          termination_helper.set_carrier_assigned_ids(en)
        end
      end
      termination_helper.set_event_action("urn:openhbx:terms:v1:enrollment#change_member_terminate")
      termination_helper.set_policy_id(existing_policy.eg_id)
      termination_helper.set_member_starts(member_date_map)
      termination_helper.set_member_end_date(member_end_date_map)
      termination_helper.filter_affected_members(dropped_dependents)
      termination_helper.replace_premium_totals(action.event_xml)
      termination_helper.keep_member_ends(dropped_dependents)
      termination_helper.swap_qualifying_event(action.event_xml)
      publish_edi(amqp_connection, termination_helper.to_xml, existing_policy.eg_id, termination.employer_hbx_id)
    end
  end
end
