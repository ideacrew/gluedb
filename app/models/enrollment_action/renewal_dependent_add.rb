module EnrollmentAction
  class RenewalDependentAdd < Base
    extend RenewalComparisonHelper

    def self.qualifies?(chunk)
      return false if chunk.length > 1
      return false if chunk.first.is_termination?
      return false if chunk.first.is_passive_renewal?
      renewal_candidates = same_carrier_renewal_candidates(chunk.first)
      return false if renewal_candidates.empty?
      renewal_dependents_added?(renewal_candidates.first, chunk.first)
    end

    def added_dependents
      renewal_candidates = self.class.same_carrier_renewal_candidates(action)
      action.all_member_ids - renewal_candidates.first.enrollees.map(&:m_id)
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
      ep.persist
    end

    def publish
      amqp_connection = action.event_responder.connection
      action_helper = EnrollmentAction::ActionPublishHelper.new(action.event_xml)
      if action.renewal_cancel_policy.present? && action.existing_policy.carrier.canceled_renewal_causes_new_coverage
        action_helper.set_event_action("urn:openhbx:terms:v1:enrollment#initial")
      else
        action_helper.set_event_action("urn:openhbx:terms:v1:enrollment#active_renew_member_add")
        action_helper.filter_affected_members(added_dependents)
      end
      enrollees = action.existing_policy.try(:enrollees)
      if enrollees.present?
        enrollees.each do |en|
          if en.c_id.present? || en.cp_id.present?
            action_helper.set_member_level_carrier_assigned_ids(en)
            action_helper.set_policy_level_carrier_assigned_ids(en)
          end
        end
      end
      action_helper.keep_member_ends([])
      publish_edi(amqp_connection, action_helper.to_xml, action.hbx_enrollment_id, action.employer_hbx_id)
    end
  end
end
