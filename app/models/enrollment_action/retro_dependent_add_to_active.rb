module EnrollmentAction
  class RetroDependentAddToActive < Base
    extend PlanComparisonHelper
    extend DependentComparisonHelper

    def self.qualifies_3?(chunk)
      qualifies?(chunk)
    end

    def self.qualifies?(chunk)
      #[retro term/cancel, current cancel, retro add]
      return false if chunk.length < 3
      return false if chunk.first.is_shop?
      return false unless same_plan?([chunk.first, chunk.last])
      chunk.second.is_cancel? && dependents_added?([chunk.first, chunk.last])
    end

    def added_dependents
      action.all_member_ids - termination.all_member_ids
    end

    def renewal_candidate
      same_carrier_renewal_candidates(action).first
    end

    def persist
      policy_to_change = termination.existing_policy
      return false unless policy_to_change
      members = action.policy_cv.enrollees.map(&:member)
      members_persisted = members.map do |mem|
        em = ExternalEvents::ExternalMember.new(mem)
        em.persist
      end
      unless members_persisted.all?
        return false
      end
      policy_to_change.hbx_enrollment_ids << action.hbx_enrollment_id
      policy_to_change.save!
      pol_updater = ExternalEvents::ExternalPolicyMemberAdd.new(
          policy_to_change,
          action.policy_cv,
          added_dependents)
      pol_updater.subscriber_start(action.subscriber_start)
      pol_updater.persist
    end

    def publish
      amqp_connection = termination.event_responder.connection
      policy_to_change = termination.existing_policy
      change_publish_helper = EnrollmentAction::ActionPublishHelper.new(action.event_xml)
      enrollees = policy_to_change.try(:enrollees)
      if enrollees.present?
        enrollees.each do |en|
          if en.c_id.present? || en.cp_id.present?
            change_publish_helper.set_carrier_assigned_ids(en)
          end
        end
      end
      member_date_map = {}
      policy_to_change.enrollees.each do |en|
        member_date_map[en.m_id] = en.coverage_start
      end
      change_publish_helper.set_policy_id(policy_to_change.eg_id)
      change_publish_helper.set_member_starts(member_date_map)
      change_publish_helper.filter_affected_members(added_dependents)
      change_publish_helper.set_event_action("urn:openhbx:terms:v1:enrollment#change_member_add")
      change_publish_helper.keep_member_ends([])
      publish_edi(amqp_connection, change_publish_helper.to_xml, termination.hbx_enrollment_id, termination.employer_hbx_id)
    end
  end
end
