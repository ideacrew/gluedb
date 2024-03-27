require "rails_helper"

describe ::ExternalEvents::EnrollmentEventNotificationFilters::RemoveSameActionsAndSelectSilent, "given, in order:
- a loud termination event for enrollment 'A'
- a silent termination for enrollment 'A'
" do

  let(:event_1) do
    instance_double(
      ::ExternalEvents::EnrollmentEventNotification,
      :hbx_enrollment_id => "A",
      :enrollment_action => "terminate",
      :is_publishable? => true,
      :is_termination? => true
    )
  end

  let(:event_2) do
    instance_double(
      ::ExternalEvents::EnrollmentEventNotification,
      :hbx_enrollment_id => "A",
      :enrollment_action => "terminate",
      :is_publishable? => false,
      :is_termination? => true
    )
  end

  let(:events) { [event_1, event_2] }

  before :each do
    allow(event_1).to receive(:drop_payload_duplicate!)
  end

  it "filters the loud termination event" do
    expect(subject.filter(events)).not_to include(event_1)
  end

  it "includes the silent termination event" do
    expect(subject.filter(events)).to include(event_2)
  end

  it "drops the loud termination event as a duplicate" do
    expect(event_1).to receive(:drop_payload_duplicate!)
    subject.filter(events)
  end

end

describe ::ExternalEvents::EnrollmentEventNotificationFilters::RemoveSameActionsAndSelectSilent, "given, in order:
- a silent termination for enrollment 'A'
- a loud termination event for enrollment 'A'
" do

  let(:event_1) do
    instance_double(
      ::ExternalEvents::EnrollmentEventNotification,
      :hbx_enrollment_id => "A",
      :enrollment_action => "terminate",
      :is_publishable? => true,
      :is_termination? => true
    )
  end

  let(:event_2) do
    instance_double(
      ::ExternalEvents::EnrollmentEventNotification,
      :hbx_enrollment_id => "A",
      :enrollment_action => "terminate",
      :is_publishable? => false,
      :is_termination? => true
    )
  end

  let(:events) { [event_2, event_1] }

  before :each do
    allow(event_1).to receive(:drop_payload_duplicate!)
  end

  it "filters the loud termination event" do
    expect(subject.filter(events)).not_to include(event_1)
  end

  it "includes the silent termination event" do
    expect(subject.filter(events)).to include(event_2)
  end

  it "drops the loud termination event as a duplicate" do
    expect(event_1).to receive(:drop_payload_duplicate!)
    subject.filter(events)
  end

end

describe ::ExternalEvents::EnrollmentEventNotificationFilters::RemoveSameActionsAndSelectSilent, "given, in order:
- a coverage_selected for enrollment 'A'
- an auto_renew for enrollment 'A'
" do

  let(:event_1) do
    instance_double(
      ::ExternalEvents::EnrollmentEventNotification,
      :hbx_enrollment_id => "A",
      :enrollment_action => "urn:openhbx:terms:v1:enrollment#initial",
      :is_publishable? => true,
      :is_termination? => false,
      :is_coverage_starter? => true,
      :is_passive_renewal? => false
    )
  end

  let(:event_2) do
    instance_double(
      ::ExternalEvents::EnrollmentEventNotification,
      :hbx_enrollment_id => "A",
      :enrollment_action => "urn:openhbx:terms:v1:enrollment#auto_renew",
      :is_publishable? => false,
      :is_termination? => false,
      :is_coverage_starter? => true,
      :is_passive_renewal? => true
    )
  end

  let(:events) { [event_1, event_2] }

  before :each do
    allow(event_1).to receive(:drop_payload_duplicate!)
  end

  it "filters the coverage_selected event" do
    expect(subject.filter(events)).not_to include(event_1)
  end

  it "includes the auto_renewal event" do
    expect(subject.filter(events)).to include(event_2)
  end

  it "drops the coverage_selected event as a duplicate" do
    expect(event_1).to receive(:drop_payload_duplicate!)
    subject.filter(events)
  end

end

describe ::ExternalEvents::EnrollmentEventNotificationFilters::RemoveSameActionsAndSelectSilent, "given, in order:
- an auto_renewal for enrollment 'A'
- a coverage_selected for enrollment 'A'
" do

  let(:event_1) do
    instance_double(
      ::ExternalEvents::EnrollmentEventNotification,
      :hbx_enrollment_id => "A",
      :enrollment_action => "urn:openhbx:terms:v1:enrollment#auto_renew",
      :is_publishable? => true,
      :is_termination? => false,
      :is_coverage_starter? => true,
      :is_passive_renewal? => true
    )
  end

  let(:event_2) do
    instance_double(
      ::ExternalEvents::EnrollmentEventNotification,
      :hbx_enrollment_id => "A",
      :enrollment_action => "urn:openhbx:terms:v1:enrollment#initial",
      :is_publishable? => false,
      :is_termination? => false,
      :is_coverage_starter? => true,
      :is_passive_renewal? => false
    )
  end

  let(:events) { [event_1, event_2] }

  before :each do
    allow(event_2).to receive(:drop_payload_duplicate!)
  end

  it "filters the coverage_selected event" do
    expect(subject.filter(events)).not_to include(event_2)
  end

  it "includes the auto_renewal event" do
    expect(subject.filter(events)).to include(event_1)
  end

  it "drops the coverage_selected event as a duplicate" do
    expect(event_2).to receive(:drop_payload_duplicate!)
    subject.filter(events)
  end

end