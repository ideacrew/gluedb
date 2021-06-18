module EnrollmentAction
  class RetroAddAndTerm < Base
    include NotificationExemptionHelper
    extend RenewalComparisonHelper

    def self.qualifies?(chunk)
      # Adding coverage to retro year and cancel current coverage.
      return false if chunk.length < 2
      return false unless (!chunk.first.is_termination? && chunk.last.is_cancel?)
      return false unless chunk.first.active_year != chunk.last.active_year
      return false unless chunk.first.coverage_year
      (chunk.first.coverage_year.end == chunk.last.subscriber_start - 1.day) && chunk.first.coverage_year.include?(chunk.first.subscriber_start)
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
    end
  end
end
