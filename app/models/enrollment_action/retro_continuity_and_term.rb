module EnrollmentAction
  class RetroContinuityAndTerm < Base
    include NotificationExemptionHelper
    extend RenewalComparisonHelper

    def self.qualifies?(chunk)
      return false if chunk.length < 3
      # 3 events [prior_cov, current_cov_term, renewal_cov_for_prior]
      return false unless chunk.second.is_termination?
      continued_coverage_renewal_candidates?(chunk.first, chunk.last)
    end

    def persist
      if termination.existing_policy
        policy_to_term = termination.existing_policy
        existing_npt = policy_to_term.term_for_np
        policy_to_term.terminate_as_of(termination.subscriber_end)
        unless termination_event_exempt_from_notification?(policy_to_term, termination.subscriber_end, true, existing_npt)
          Observers::PolicyUpdated.notify(policy_to_term)
        end
      end
      return false if check_already_exists
      [action, additional_action].each do |action|
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
    end

    def publish
      amqp_connection = termination.event_responder.connection

      term_policy = termination.existing_policy
      term_policy.reload
      member_date_map = {}
      term_policy.enrollees.each do |en|
        member_date_map[en.m_id] = en.coverage_start
      end

      term_helper = ActionPublishHelper.new(termination.event_xml)
      term_helper.set_event_action("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
      term_helper.set_policy_id(term_policy.eg_id)
      term_helper.set_member_starts(member_date_map)
      publish_edi(amqp_connection, term_helper.to_xml, termination.hbx_enrollment_id, termination.employer_hbx_id)

      action_helper = ActionPublishHelper.new(action.event_xml)
      action_helper.set_event_action("urn:openhbx:terms:v1:enrollment#initial")
      action_helper.keep_member_ends([])
      publish_edi(amqp_connection, action_helper.to_xml, action.hbx_enrollment_id, action.employer_hbx_id)

      renewal_helper = ActionPublishHelper.new(additional_action.event_xml)
      renewal_helper.set_event_action("urn:openhbx:terms:v1:enrollment#auto_renew")
      renewal_helper.keep_member_ends([])
      publish_edi(amqp_connection, renewal_helper.to_xml, additional_action.hbx_enrollment_id, additional_action.employer_hbx_id)
    end
  end
end
