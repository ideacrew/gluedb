require 'rails_helper'

describe EnrollmentAction::AssistanceChange, "given an enrollment event set that:
- is the same plan
- with no dependents changed
- and aptc unchanged" do
  let(:plan) { instance_double(Plan, :id => 1, carrier_id: 1) }
  let(:new_plan) { instance_double(Plan, :id => 1, carrier_id: 1) }

  let(:aptc_amount_1) { "1234.00" }
  let(:aptc_amount_2) { " 1234.00" }
  let(:policy_enrollment_1) { instance_double(Openhbx::Cv2::PolicyEnrollment, :individual_market => ivl_policy_enrollment_1) }
  let(:ivl_policy_enrollment_1) { instance_double(Openhbx::Cv2::PolicyEnrollmentIndividualMarket, applied_aptc_amount: aptc_amount_1) }
  let(:policy_cv_1) { instance_double(Openhbx::Cv2::Policy, :policy_enrollment => policy_enrollment_1) }
  let(:policy_enrollment_2) { instance_double(Openhbx::Cv2::PolicyEnrollment, :individual_market => ivl_policy_enrollment_2) }
  let(:ivl_policy_enrollment_2) { instance_double(Openhbx::Cv2::PolicyEnrollmentIndividualMarket, applied_aptc_amount: aptc_amount_2) }
  let(:policy_cv_2) { instance_double(Openhbx::Cv2::Policy, :policy_enrollment => policy_enrollment_2) }

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => plan, :all_member_ids => [1,2], :is_shop? => false, :policy_cv => policy_cv_1) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => new_plan, :all_member_ids => [1,2], :is_shop? => false, :policy_cv => policy_cv_2) }
  let(:event_set) { [event_1, event_2] }

  subject { EnrollmentAction::AssistanceChange }

  it "doesn't qualify" do
    expect(subject.qualifies?(event_set)).to be_falsey
  end
end

describe EnrollmentAction::AssistanceChange, "given an enrollment event set that:
- is the same plan
- with no dependents changed
- and aptc changed" do
  let(:plan) { instance_double(Plan, :id => 1, carrier_id: 1) }
  let(:new_plan) { instance_double(Plan, :id => 1, carrier_id: 1) }

  let(:aptc_amount_1) { "1234.01" }
  let(:aptc_amount_2) { " 1234.00" }
  let(:policy_enrollment_1) { instance_double(Openhbx::Cv2::PolicyEnrollment, :individual_market => ivl_policy_enrollment_1) }
  let(:ivl_policy_enrollment_1) { instance_double(Openhbx::Cv2::PolicyEnrollmentIndividualMarket, applied_aptc_amount: aptc_amount_1) }
  let(:policy_cv_1) { instance_double(Openhbx::Cv2::Policy, :policy_enrollment => policy_enrollment_1) }
  let(:policy_enrollment_2) { instance_double(Openhbx::Cv2::PolicyEnrollment, :individual_market => ivl_policy_enrollment_2) }
  let(:ivl_policy_enrollment_2) { instance_double(Openhbx::Cv2::PolicyEnrollmentIndividualMarket, applied_aptc_amount: aptc_amount_2) }
  let(:policy_cv_2) { instance_double(Openhbx::Cv2::Policy, :policy_enrollment => policy_enrollment_2) }

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => plan, :all_member_ids => [1,2], :is_shop? => false, :policy_cv => policy_cv_1) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => new_plan, :all_member_ids => [1,2], :is_shop? => false, :policy_cv => policy_cv_2) }
  let(:event_set) { [event_1, event_2] }

  subject { EnrollmentAction::AssistanceChange }

  it "qualifies" do
    expect(subject.qualifies?(event_set)).to be_truthy
  end
end

describe EnrollmentAction::AssistanceChange, "being published" do
  let(:event_xml) { double }
  let(:action_helper_result_xml) { double }
  let(:amqp_connection) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }

  let(:enrollee_primary) { double(:m_id => 1, :coverage_start => :one_month_ago, :c_id => nil, :cp_id => nil) }
  let(:enrollee_new) { double(:m_id => 2, :coverage_start => :one_month_ago, :c_id => nil, :cp_id => nil) }
  let(:policy) { instance_double(Policy, :enrollees => [enrollee_primary, enrollee_new], :eg_id => 1) }

  let(:subscriber_start) { double }

  let(:termination_event) do
    instance_double(
      ::ExternalEvents::EnrollmentEventNotification,
      :existing_policy => policy
    )
  end

  let(:new_enrollment_event) do
    instance_double(
      ::ExternalEvents::EnrollmentEventNotification,
      :event_xml => event_xml,
      :event_responder => event_responder,
      :subscriber_start => subscriber_start,
      :hbx_enrollment_id => double,
      :employer_hbx_id => nil
    )
  end

  let(:action_publish_helper) { instance_double(
    EnrollmentAction::ActionPublishHelper,
    :to_xml => action_helper_result_xml
  ) }

  subject do
    EnrollmentAction::AssistanceChange.new(termination_event, new_enrollment_event)
  end

  before :each do
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).and_return(action_publish_helper)
    allow(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#change_financial_assistance")
    allow(action_publish_helper).to receive(:set_policy_id).with(1)
    allow(action_publish_helper).to receive(:set_member_starts).with({ 1 => :one_month_ago, 2 => :one_month_ago })
    allow(action_publish_helper).to receive(:keep_member_ends).with([])
    allow(action_publish_helper).to receive(:assign_assistance_date).with(subscriber_start)
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, new_enrollment_event.hbx_enrollment_id, new_enrollment_event.employer_hbx_id)
  end

  it "publishes the new edi" do
    expect(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, new_enrollment_event.hbx_enrollment_id, new_enrollment_event.employer_hbx_id)
    subject.publish
  end

  it "sets the assistance effective date from the new enrollment" do
    allow(action_publish_helper).to receive(:assign_assistance_date).with(subscriber_start)
    subject.publish
  end

  it "clears the end dates" do
    expect(action_publish_helper).to receive(:keep_member_ends).with([])
    subject.publish
  end

  it "sets the original start dates" do
    allow(action_publish_helper).to receive(:set_member_starts).with({ 1 => :one_month_ago, 2 => :one_month_ago })
    subject.publish
  end

  it "publishes an event of type assistance change" do
    expect(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#change_financial_assistance")
    subject.publish
  end

  it "sets the policy id to that of the existing policy" do
    expect(action_publish_helper).to receive(:set_policy_id).with(1)
    subject.publish
  end
end

describe EnrollmentAction::AssistanceChange, "being persisted" do
  let(:hbx_enrollment_id) { double }
  let(:policy_cv) { double }
  let(:existing_enrollment_ids) { double }
  let(:policy) { instance_double(Policy, :hbx_enrollment_ids => existing_enrollment_ids) }

  let(:termination_event) do
    instance_double(
      ::ExternalEvents::EnrollmentEventNotification,
      :existing_policy => policy
    )
  end

  let(:new_enrollment_event) do
    instance_double(
      ::ExternalEvents::EnrollmentEventNotification,
      :hbx_enrollment_id => hbx_enrollment_id
    )
  end

  let(:policy_updater) do
    instance_double(ExternalEvents::ExternalPolicyAssistanceChange)
  end

  subject do
    EnrollmentAction::AssistanceChange.new(termination_event, new_enrollment_event)
  end

  before :each do
    allow(ExternalEvents::ExternalPolicyAssistanceChange).to receive(:new).with(policy, new_enrollment_event).and_return(policy_updater)
    allow(policy).to receive(:save!).and_return(true)
    allow(policy_updater).to receive(:persist).and_return(true)
    allow(existing_enrollment_ids).to receive(:<<).with(hbx_enrollment_id)
  end

  it "adds the hbx_enrollment_id to the list on the policy" do
    expect(existing_enrollment_ids).to receive(:<<).with(hbx_enrollment_id)
    subject.persist
  end

  it "updates the assistance" do
    expect(policy_updater).to receive(:persist).and_return(true)
    subject.persist
  end
end
