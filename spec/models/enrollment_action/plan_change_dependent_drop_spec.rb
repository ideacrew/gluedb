require 'rails_helper'

describe EnrollmentAction::PlanChangeDependentDrop, "given an EnrollmentAction array that:
  - has less than two elements
  - is the same plan
  - doesn't have the same carrier
  - has no dropped dependents
  - is not the same plan, has the same carrier, and has dropped dependents" do

  let(:plan_1) { instance_double(Plan, id: 1, carrier_id: 1) }
  let(:plan_2) { instance_double(Plan, id: 2, carrier_id: 2) }
  let(:plan_3) { instance_double(Plan, id: 3, carrier_id: 2) }
  let(:plan_4) { instance_double(Plan, id: 1, carrier_id: 1) }
  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, existing_plan: plan_1, all_member_ids: [1, 2, 3]) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification, existing_plan: plan_4, all_member_ids: [1, 2]) }
  let(:event_3) { instance_double(ExternalEvents::EnrollmentEventNotification, existing_plan: plan_2, all_member_ids: [1, 2]) }
  let(:event_4) { instance_double(ExternalEvents::EnrollmentEventNotification, existing_plan: plan_3, all_member_ids: [1, 2, 3]) }
  let(:event_5) { instance_double(ExternalEvents::EnrollmentEventNotification, existing_plan: plan_3, all_member_ids: [1, 2]) }

  subject { EnrollmentAction::PlanChangeDependentDrop }

  it "does not qualify because it has less than two elements" do
    expect(subject.qualifies?([event_1])).to be_false
  end

  it "does not qualify because both elements are the same plan" do
    expect(subject.qualifies?([event_1, event_2])).to be_false
  end

  it "does not qualify because the carrier IDs are different" do
    expect(subject.qualifies?([event_1, event_3])).to be_false
  end

  it "does not qualify because there are no dropped dependents" do
    expect(subject.qualifies?([event_1, event_4])).to be_false
  end

  it "qualifies" do
    expect(subject.qualifies?([event_4, event_3])).to be_truthy
  end
end

describe EnrollmentAction::PlanChangeDependentDrop, "given a valid enrollment set
  - with dropped dependents
  - with no dropped dependents, return an empty array" do

  let(:primary_member) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:secondary_member) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 2) }
  let(:dropped_member) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 3) }
  let(:terminated_policy_cv) { instance_double(Openhbx::Cv2::Policy, enrollees: [primary_member, secondary_member, dropped_member])}
  let(:new_policy_cv) { instance_double(Openhbx::Cv2::Policy, enrollees: [primary_member, secondary_member]) }
  let(:plan) { instance_double(Plan, id: 1) }
  let(:policy) { instance_double(Policy, hbx_enrollment_ids: [1, 2, 3]) }
  let(:dependent_drop_event_1) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    policy_cv: new_policy_cv,
    existing_plan: plan,
    all_member_ids: [1, 2],
    hbx_enrollment_id: 1
  ) }
  let(:dependent_drop_event_2) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    policy_cv: new_policy_cv,
    existing_plan: plan,
    all_member_ids: [1, 2, 3],
    hbx_enrollment_id: 1
  ) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    policy_cv: terminated_policy_cv,
    existing_policy: policy,
    all_member_ids: [1, 2, 3]
  ) }
  let(:policy_updater) { instance_double(ExternalEvents::ExternalPolicyMemberDrop) }

  def has_dropped_dependent; EnrollmentAction::PlanChangeDependentDrop.new(termination_event, dependent_drop_event_1); end
  def no_dropped_dependent; EnrollmentAction::PlanChangeDependentDrop.new(termination_event, dependent_drop_event_2); end

  it "return an array containing the dropped dependents" do
    expect(has_dropped_dependent.dropped_dependents).to eq([3])
  end

  it "return an empty array" do
    expect(no_dropped_dependent.dropped_dependents).to eq([])
  end
end

describe EnrollmentAction::PlanChangeDependentDrop, "given a valid enrollment set" do
  let(:primary_member) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:secondary_member) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 2) }
  let(:dropped_member) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 3) }
  let(:primary_enrollee) { instance_double(Openhbx::Cv2::Enrollee, member: primary_member) }
  let(:secondary_enrollee) { instance_double(Openhbx::Cv2::Enrollee, member: primary_member) }
  let(:dropped_enrollee) { instance_double(Openhbx::Cv2::Enrollee, member: primary_member) }
  let(:terminated_policy_cv) { instance_double(Openhbx::Cv2::Policy, enrollees: [primary_enrollee, secondary_enrollee, dropped_enrollee])}
  let(:new_policy_cv) { instance_double(Openhbx::Cv2::Policy, enrollees: [primary_enrollee, secondary_enrollee]) }
  let(:plan) { instance_double(Plan, id: 1) }
  let(:policy) { instance_double(Policy, hbx_enrollment_ids: [1, 2, 3]) }
  let(:db_record) { instance_double(ExternalEvents::ExternalMember, persist: true) }
  let(:dependent_drop_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    policy_cv: new_policy_cv,
    existing_plan: plan,
    all_member_ids: [1, 2],
    hbx_enrollment_id: 3
  ) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    policy_cv: terminated_policy_cv,
    existing_policy: policy,
    all_member_ids: [1, 2, 3]
  ) }
  let(:policy_updater) { instance_double(ExternalEvents::ExternalPolicyMemberDrop) }

  subject { EnrollmentAction::PlanChangeDependentDrop.new(termination_event, dependent_drop_event) }

  before :each do
    allow(ExternalEvents::ExternalMember).to receive(:new).with(primary_member).and_return(db_record)
    allow(ExternalEvents::ExternalMember).to receive(:new).with(secondary_member).and_return(db_record)
    allow(ExternalEvents::ExternalMember).to receive(:new).with(dropped_member).and_return(db_record)
    allow(ExternalEvents::ExternalPolicy).to receive(:new).with(new_policy_cv, plan).and_return(policy_updater)
    allow(policy_updater).to receive(:persist).and_return(true)
    allow(termination_event).to receive(:subscriber_end).and_return(false)
    allow(termination_event.existing_policy).to receive(:terminate_as_of).and_return(true)
  end

  it "persists when all members persist" do
    expect(subject.persist).to be_truthy
  end
end

describe EnrollmentAction::PlanChangeDependentDrop, "given a valid enrollment" do
  let(:amqp_connection) { double }
  let(:event_xml) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, connection: amqp_connection) }
  let(:enrollee) { double(m_id: 1, coverage_start: :one_month_ago) }
  let(:new_enrollee) { double(m_id: 2, coverage_start: :one_month_ago) }
  let(:plan) { instance_double(Plan, id: 1) }
  let(:policy) { instance_double(Policy, id: 1, enrollees: [enrollee, new_enrollee], eg_id: 1) }
  let(:dependent_drop_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    event_xml: event_xml,
    all_member_ids: [1, 2],
    hbx_enrollment_id: 1,
    employer_hbx_id: 1
  ) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    event_xml: event_xml,
    existing_policy: policy,
    all_member_ids: [1, 2, 3],
    event_responder: event_responder,
    hbx_enrollment_id: 1,
    employer_hbx_id: 1
  ) }
  let(:action_helper_result_xml) { double }
  let(:action_helper) { instance_double(
    EnrollmentAction::ActionPublishHelper,
    to_xml: action_helper_result_xml
  ) }

  subject { EnrollmentAction::PlanChangeDependentDrop.new(termination_event, dependent_drop_event) }

  before :each do
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).and_return(action_helper)
    allow(action_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#change_member_terminate")
    allow(action_helper).to receive(:set_policy_id).with(policy.id)
    allow(action_helper).to receive(:set_member_starts).with({1 => enrollee.coverage_start, 2 => new_enrollee.coverage_start})
    allow(action_helper).to receive(:filter_affected_members).with([3]).and_return(true)
    allow(action_helper).to receive(:keep_member_ends).with([3])
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, dependent_drop_event.hbx_enrollment_id, dependent_drop_event.employer_hbx_id)
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, dependent_drop_event.hbx_enrollment_id, dependent_drop_event.employer_hbx_id)
    allow(action_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#change_product")
    allow(action_helper).to receive(:keep_member_ends).with([])
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, termination_event.hbx_enrollment_id, termination_event.employer_hbx_id)
  end

  it "receives set_event_action" do
    expect(action_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#change_product")
    subject.publish
  end

  it "receives set_policy_id" do
    expect(action_helper).to receive(:set_policy_id).with(1)
    subject.publish
  end

  it "receives set_member_starts" do
    expect(action_helper).to receive(:set_member_starts).with({1 => enrollee.coverage_start, 2 => new_enrollee.coverage_start})
    subject.publish
  end

  it "receives filter_affected_members" do
    expect(action_helper).to receive(:filter_affected_members).with([3])
    subject.publish
  end

  it "receives keep_member_ends" do
    expect(action_helper).to receive(:keep_member_ends).with([3])
    subject.publish
  end

  it "publishes resulting xml to edi" do
    expect(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, termination_event.hbx_enrollment_id, termination_event.employer_hbx_id)
    subject.publish
  end
end
