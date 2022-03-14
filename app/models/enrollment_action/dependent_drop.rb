module EnrollmentAction
  class DependentDrop < Base
    extend PlanComparisonHelper
    extend DependentComparisonHelper
    include RenewalComparisonHelper
    include TerminationDateHelper

    attr_accessor :dep_drop_from_renewal

    def self.qualifies?(chunk)
      return false if chunk.length < 2
      return false unless same_plan?(chunk)
      dependents_dropped?(chunk)
    end

    # TODO: Terminate members
    def persist
      policy_to_change = termination.existing_policy
      binding.pry
      @dep_drop_from_renewal = policy_to_change.carrier.renewal_dependent_drop_transmitted_as_renewal && action.dep_add_or_drop_to_renewal_policy?(renewal_candidate, policy_to_change)
      if @dep_drop_from_renewal
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
        policy_to_change.cancel_via_hbx!
        true
      else
        policy_to_change.hbx_enrollment_ids << action.hbx_enrollment_id
        policy_to_change.save
        pol_updater = ExternalEvents::ExternalPolicyMemberDrop.new(policy_to_change, termination.policy_cv, dropped_dependents)
        pol_updater.use_totals_from(action.policy_cv)
        pol_updater.subscriber_start(action.subscriber_start)
        pol_updater.member_drop_date(select_termination_date)
        pol_updater.persist
        true
      end
    end

    def dropped_dependents
      termination.all_member_ids - action.all_member_ids
    end

    def renewal_candidate
      same_carrier_renewal_candidates(action).first
    end

    def publish
      amqp_connection = termination.event_responder.connection
      existing_policy = termination.existing_policy
      if @dep_drop_from_renewal
        action_helper = ActionPublishHelper.new(action.event_xml)
        action_helper.set_event_action("urn:openhbx:terms:v1:enrollment#auto_renew")
        action_helper.keep_member_ends([])
        enrollees = existing_policy.try(:enrollees)
        if enrollees.present?
          enrollees.each do |en|
            if en.c_id.present? || en.cp_id.present?
              action_helper.set_carrier_assigned_ids(en)
            end
          end
        end
        publish_edi(amqp_connection, action_helper.to_xml, action.hbx_enrollment_id, action.employer_hbx_id)
      else
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
end
