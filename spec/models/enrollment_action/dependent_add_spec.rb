require "rails_helper"

describe EnrollmentAction::DependentAdd, "given an enrollment event set that:
- has two enrollments
- the first enrollment is a cancel for plan A
- the second enrollment is a start for plan A
- the second enrollment has more members" do

  let(:plan) { instance_double(Plan, :id => 1) }

  let(:member_ids_1) { [1,2] }
  let(:member_ids_2) { [1,2,3] }

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => plan, :all_member_ids => member_ids_1) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => plan, :all_member_ids => member_ids_2) }
  let(:event_set) { [event_1, event_2] }

  subject { EnrollmentAction::DependentAdd }

  it "qualifies" do
    expect(subject.qualifies?(event_set)).to be_truthy
  end
end

describe EnrollmentAction::DependentAdd, "given a qualified enrollment set, being persisted" do
  let(:member_primary) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:member_secondary) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 2) }
  let(:member_new) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 3) }
  let(:enrollee_primary) { instance_double(::Openhbx::Cv2::Enrollee, :member => member_primary) }
  let(:enrollee_secondary) { instance_double(::Openhbx::Cv2::Enrollee, :member => member_secondary) }
  let(:enrollee_new) { instance_double(::Openhbx::Cv2::Enrollee, :member => member_new) }

  let(:terminated_policy_cv) { instance_double(Openhbx::Cv2::Policy, :enrollees => [enrollee_primary, enrollee_secondary])}
  let(:new_policy_cv) { instance_double(Openhbx::Cv2::Policy, :enrollees => [enrollee_primary, enrollee_secondary, enrollee_new]) }
  let(:plan) { instance_double(Plan, :id => 1) }
  let(:policy) { instance_double(Policy, :hbx_enrollment_ids => [1,2]) }
  let(:primary_db_record) { instance_double(ExternalEvents::ExternalMember, :persist => true) }
  let(:secondary_db_record) { instance_double(ExternalEvents::ExternalMember, :persist => true) }
  let(:new_db_record) { instance_double(ExternalEvents::ExternalMember, :persist => true) }

  let(:dependent_add_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :policy_cv => new_policy_cv,
    :existing_plan => plan,
    :all_member_ids => [1,2,3],
    :hbx_enrollment_id => 3
    ) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :policy_cv => terminated_policy_cv,
    :existing_policy => policy,
    :all_member_ids => [1,2]
    ) }

  let(:policy_updater) { instance_double(ExternalEvents::ExternalPolicyMemberAdd) }


  subject do
    EnrollmentAction::DependentAdd.new(termination_event, dependent_add_event)
  end

  before :each do
    allow(ExternalEvents::ExternalMember).to receive(:new).with(member_primary).and_return(primary_db_record)
    allow(ExternalEvents::ExternalMember).to receive(:new).with(member_secondary).and_return(secondary_db_record)
    allow(ExternalEvents::ExternalMember).to receive(:new).with(member_new).and_return(new_db_record)

    allow(policy).to receive(:save!).and_return(true)
    allow(ExternalEvents::ExternalPolicyMemberAdd).to receive(:new).with(policy, new_policy_cv, [3]).and_return(policy_updater)
    allow(policy_updater).to receive(:persist).and_return(true)
  end

  it "successfully creates the new policy" do
    expect(subject.persist).to be_truthy
  end
end

describe EnrollmentAction::DependentAdd, "given a qualified enrollment set, being published" do
  let(:amqp_connection) { double }
  let(:event_xml) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
  let(:enrollee_primary) { double(:m_id => 1, :coverage_start => :one_month_ago) }
  let(:enrollee_new) { double(:m_id => 2, :coverage_start => :one_month_ago) }

  let(:plan) { instance_double(Plan, :id => 1) }
  let(:policy) { instance_double(Policy, :enrollees => [enrollee_primary, enrollee_new], :eg_id => 1) }

  let(:dependent_add_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :event_xml => event_xml,
    :all_member_ids => [1,2],
    :hbx_enrollment_id => 2
  ) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :existing_policy => policy,
    :all_member_ids => [1],
    :event_responder => event_responder,
    :hbx_enrollment_id => 1,
    :employer_hbx_id => 1
  ) }
  let(:action_helper_result_xml) { double }

  let(:action_publish_helper) { instance_double(
    EnrollmentAction::ActionPublishHelper,
    :to_xml => action_helper_result_xml
  ) }

  before :each do
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).and_return(action_publish_helper)
    allow(action_publish_helper).to receive(:set_policy_id).with(1).and_return(true)
    allow(action_publish_helper).to receive(:filter_affected_members).with([2]).and_return(true)
    allow(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#change_member_add")
    allow(action_publish_helper).to receive(:set_member_starts).with({ 1 => :one_month_ago, 2 => :one_month_ago })
    allow(action_publish_helper).to receive(:keep_member_ends).with([])
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, termination_event.hbx_enrollment_id, termination_event.employer_hbx_id)
    allow(subject).to receive(:is_renewal_policy?).and_return(false)
  end

  subject do
    EnrollmentAction::DependentAdd.new(termination_event, dependent_add_event)
  end

  it "publishes an event of type add dependents" do
    expect(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#change_member_add")
    subject.publish
  end

  it "sets member start dates" do
    expect(action_publish_helper).to receive(:set_member_starts).with({ 1 => :one_month_ago, 2 => :one_month_ago })
    subject.publish
  end

  it "clears all member end dates before publishing" do
    expect(action_publish_helper).to receive(:keep_member_ends).with([])
    subject.publish
  end

  it "publishes resulting xml to edi" do
    expect(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, termination_event.hbx_enrollment_id, termination_event.employer_hbx_id)
    subject.publish
  end

  it "publishes an event of type add dependents" do
    allow(subject).to receive(:is_renewal_policy?).and_return(true)
    expect(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#auto_renew")
    subject.publish
  end
end
