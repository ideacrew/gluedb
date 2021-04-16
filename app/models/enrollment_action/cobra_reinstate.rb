module EnrollmentAction
  class CobraReinstate < Base
    extend ReinstatementComparisonHelper
    include ReinstatementComparisonHelper

    attr_accessor :existing_policy
    def self.qualifies?(chunk)
      return false if chunk.length > 1
      return false if chunk.first.is_termination?
      return false unless chunk.first.is_cobra?
      same_carrier_reinstatement_candidates(chunk.first).any?
    end

    def persist
      @existing_policy = same_carrier_reinstatement_candidates(action).first
      policy_updater = ExternalEvents::ExternalPolicyCobraSwitch.new(action.policy_cv, @existing_policy)
      policy_updater.persist
    end

    def publish
      amqp_connection = action.event_responder.connection
      action_helper = EnrollmentAction::ActionPublishHelper.new(action.event_xml)
      member_date_map = {}
      @existing_policy.enrollees.each do |en|
        member_date_map[en.m_id] = en.coverage_start
        action_helper.set_carrier_member_id("urn:openhbx:hbx:me0:resources:v1:person:member_id##{en.c_id}") if en.c_id.present?
        action_helper.set_carrier_policy_id("urn:openhbx:hbx:me0:resources:v1:person:policy_id##{en.cp_id}") if en.cp_id.present?
      end
      action_helper.set_policy_id(@existing_policy.eg_id)
      action_helper.set_member_starts(member_date_map)
      action_helper.set_event_action("urn:openhbx:terms:v1:enrollment#reinstate_enrollment")
      action_helper.set_market_type("urn:openhbx:terms:v1:aca_marketplace#cobra")
      action_helper.keep_member_ends([])
      publish_edi(amqp_connection, action_helper.to_xml, action.hbx_enrollment_id, action.employer_hbx_id)
    end
  end
end
