require "rails_helper"

describe Handlers::EnrollmentEventReduceHandler, "given an event that has already been processed" do
  let(:next_step) { double }
  let(:filter) { instance_double(::ExternalEvents::EnrollmentEventNotificationFilters::AlreadyProcessedEvent) }
  let(:event) { instance_double(::ExternalEvents::EnrollmentEventNotification) }

  subject { Handlers::EnrollmentEventReduceHandler.new(next_step) }

  before :each do
    allow(::ExternalEvents::EnrollmentEventNotificationFilters::AlreadyProcessedEvent).to receive(:new).and_return(filter)
    allow(filter).to receive(:filter).with([event]).and_return([])
  end

  it "does not go on to the next step" do
    expect(next_step).not_to receive(:call)
    subject.call([event])
  end
end

describe Handlers::EnrollmentEventReduceHandler, "given an event that has already been processed" do
  let(:next_step) { double }
  let(:filter) { instance_double(::ExternalEvents::EnrollmentEventNotificationFilters::AlreadyProcessedEvent) }
  let(:event) { instance_double(::ExternalEvents::EnrollmentEventNotification) }

  subject { Handlers::EnrollmentEventReduceHandler.new(next_step) }

  before :each do
    allow(::ExternalEvents::EnrollmentEventNotificationFilters::AlreadyProcessedEvent).to receive(:new).and_return(filter)
    allow(filter).to receive(:filter).with([event]).and_return([])
  end

  it "does not go on to the next step" do
    expect(next_step).not_to receive(:call)
    subject.call([event])
  end
end

describe Handlers::EnrollmentEventReduceHandler, "given a termination with no end" do
  let(:next_step) { double }
  let(:filter) { instance_double(::ExternalEvents::EnrollmentEventNotificationFilters::AlreadyProcessedEvent) }
  let(:processable_terms) { instance_double(::ExternalEvents::EnrollmentEventNotificationFilters::TerminationAlreadyProcessedByCarrier) }
  let(:event) { instance_double(::ExternalEvents::EnrollmentEventNotification) }
  let(:bad_term_filter) { instance_double(::ExternalEvents::EnrollmentEventNotificationFilters::TerminationWithoutEnd) }

  subject { Handlers::EnrollmentEventReduceHandler.new(next_step) }

  before :each do
    allow(::ExternalEvents::EnrollmentEventNotificationFilters::AlreadyProcessedEvent).to receive(:new).and_return(filter)
    allow(filter).to receive(:filter).with([event]).and_return([event])
    allow(::ExternalEvents::EnrollmentEventNotificationFilters::TerminationAlreadyProcessedByCarrier).to receive(:new).and_return(processable_terms)
    allow(processable_terms).to receive(:filter).with([event]).and_return([event])
    allow(::ExternalEvents::EnrollmentEventNotificationFilters::TerminationWithoutEnd).to receive(:new).and_return(bad_term_filter)
    allow(bad_term_filter).to receive(:filter).with([event]).and_return([])
  end

  it "does not go on to the next step" do
    expect(next_step).not_to receive(:call)
    subject.call([event])
  end
end

describe Handlers::EnrollmentEventReduceHandler, "given a termination which has already been processed" do
  let(:next_step) { double }
  let(:already_processed_filter) { instance_double(::ExternalEvents::EnrollmentEventNotificationFilters::AlreadyProcessedEvent) }
  let(:filter) { instance_double(::ExternalEvents::EnrollmentEventNotificationFilters::AlreadyProcessedTermination) }
  let(:processable_terms) { instance_double(::ExternalEvents::EnrollmentEventNotificationFilters::TerminationAlreadyProcessedByCarrier) }
  let(:event) { instance_double(::ExternalEvents::EnrollmentEventNotification) }
  let(:bad_term_filter) { instance_double(::ExternalEvents::EnrollmentEventNotificationFilters::TerminationWithoutEnd) }

  subject { Handlers::EnrollmentEventReduceHandler.new(next_step) }

  before :each do
    allow(::ExternalEvents::EnrollmentEventNotificationFilters::AlreadyProcessedEvent).to receive(:new).and_return(already_processed_filter)
    allow(already_processed_filter).to receive(:filter).with([event]).and_return([event])
    allow(::ExternalEvents::EnrollmentEventNotificationFilters::TerminationAlreadyProcessedByCarrier).to receive(:new).and_return(processable_terms)
    allow(processable_terms).to receive(:filter).with([event]).and_return([event])
    allow(::ExternalEvents::EnrollmentEventNotificationFilters::TerminationWithoutEnd).to receive(:new).and_return(bad_term_filter)
    allow(bad_term_filter).to receive(:filter).with([event]).and_return([event])
    allow(::ExternalEvents::EnrollmentEventNotificationFilters::AlreadyProcessedTermination).to receive(:new).and_return(filter)
    allow(filter).to receive(:filter).with([event]).and_return([])
  end

  it "does not go on to the next step" do
    expect(next_step).not_to receive(:call)
    subject.call([event])
  end
end

describe Handlers::EnrollmentEventReduceHandler, "given:
- 3 notifications
- 2 of which should reduce"  do
  
  let(:non_duplicate_notification) { instance_double(::ExternalEvents::EnrollmentEventNotification, :hash => 1, :drop_if_marked! => false, :bucket_id => 5, :hbx_enrollment_id => 1, :enrollment_action => "a", :drop_if_already_processed! => false, :drop_term_event_if_term_processed_by_carrier! => false) }
  let(:duplicate_notification_1) { instance_double(::ExternalEvents::EnrollmentEventNotification, :hash => 3, :drop_if_marked! => true, :hbx_enrollment_id => 2, :enrollment_action => "b", :drop_if_already_processed! => false, :drop_term_event_if_term_processed_by_carrier! => false) }
  let(:duplicate_notification_2) { instance_double(::ExternalEvents::EnrollmentEventNotification, :hash => 3, :drop_if_marked! => true, :hbx_enrollment_id => 3, :enrollment_action => "c", :drop_if_already_processed! => false, :drop_term_event_if_term_processed_by_carrier! => false) }
  let(:notifications) { [duplicate_notification_1, duplicate_notification_2, non_duplicate_notification] }
  let(:bad_term_filter) { instance_double(::ExternalEvents::EnrollmentEventNotificationFilters::TerminationWithoutEnd) }
  let(:processable_terms_filter) { instance_double(::ExternalEvents::EnrollmentEventNotificationFilters::TerminationAlreadyProcessedByCarrier) }
  let(:dupe_termination_filter) { instance_double(::ExternalEvents::EnrollmentEventNotificationFilters::AlreadyProcessedTermination) }

  let(:next_step) { double("The next step in the pipeline") }

  subject { Handlers::EnrollmentEventReduceHandler.new(next_step) }

  before :each do
    allow(::ExternalEvents::EnrollmentEventNotificationFilters::AlreadyProcessedTermination).to receive(:new).and_return(dupe_termination_filter)
    allow(dupe_termination_filter).to receive(:filter).with(notifications).and_return(notifications)
    allow(::ExternalEvents::EnrollmentEventNotificationFilters::TerminationAlreadyProcessedByCarrier).to receive(:new).and_return(processable_terms_filter)
    allow(processable_terms_filter).to receive(:filter).with(notifications).and_return(notifications)
    allow(::ExternalEvents::EnrollmentEventNotificationFilters::TerminationWithoutEnd).to receive(:new).and_return(bad_term_filter)
    allow(bad_term_filter).to receive(:filter).with(notifications).and_return(notifications)
    allow(next_step).to receive(:call).with([non_duplicate_notification])
    allow(duplicate_notification_1).to receive(:check_and_mark_duplication_against).with(duplicate_notification_2)
    allow(non_duplicate_notification).to receive(:update_business_process_history).with("Handlers::EnrollmentEventReduceHandler")
  end

  it "sends along 1 bucket with the non-reduced enrollment notification" do
    expect(next_step).to receive(:call).with([non_duplicate_notification])
    subject.call(notifications)
  end

  it "updates the business process history of the non-duplicate enrollment" do
    expect(non_duplicate_notification).to receive(:update_business_process_history).with("Handlers::EnrollmentEventReduceHandler")
    subject.call(notifications)
  end

end

describe Handlers::EnrollmentEventReduceHandler, "given:
- 3 notifications
- 2 of which should be bucketed together"  do
  
  let(:non_duplicate_notification) { instance_double(::ExternalEvents::EnrollmentEventNotification, :hash => 1, :drop_if_marked! => false, :bucket_id => 5, :hbx_enrollment_id => 1, :enrollment_action => "a", :drop_if_already_processed! => false) }
  let(:same_bucket_notification_1) { instance_double(::ExternalEvents::EnrollmentEventNotification, :hash => 3, :drop_if_marked! => false, :bucket_id => 4, :hbx_enrollment_id => 2, :enrollment_action => "b", :drop_if_already_processed! => false) }
  let(:same_bucket_notification_2) { instance_double(::ExternalEvents::EnrollmentEventNotification, :hash => 3, :drop_if_marked! => false, :bucket_id => 4, :hbx_enrollment_id => 3, :enrollment_action => "c", :drop_if_already_processed! => false) }
  let(:notifications) { [same_bucket_notification_1, same_bucket_notification_2, non_duplicate_notification] }
  let(:bad_term_filter) { instance_double(::ExternalEvents::EnrollmentEventNotificationFilters::TerminationWithoutEnd) }
  let(:processable_terms_filter) { instance_double(::ExternalEvents::EnrollmentEventNotificationFilters::TerminationAlreadyProcessedByCarrier) }
  let(:dupe_termination_filter) { instance_double(::ExternalEvents::EnrollmentEventNotificationFilters::AlreadyProcessedTermination) }

  let(:next_step) { double("The next step in the pipeline") }

  subject { Handlers::EnrollmentEventReduceHandler.new(next_step) }

  before :each do
    allow(::ExternalEvents::EnrollmentEventNotificationFilters::AlreadyProcessedTermination).to receive(:new).and_return(dupe_termination_filter)
    allow(dupe_termination_filter).to receive(:filter).with(notifications).and_return(notifications)
    allow(::ExternalEvents::EnrollmentEventNotificationFilters::TerminationAlreadyProcessedByCarrier).to receive(:new).and_return(processable_terms_filter)
    allow(processable_terms_filter).to receive(:filter).with(notifications).and_return(notifications)
    allow(::ExternalEvents::EnrollmentEventNotificationFilters::TerminationWithoutEnd).to receive(:new).and_return(bad_term_filter)
    allow(bad_term_filter).to receive(:filter).with(notifications).and_return(notifications)
    allow(next_step).to receive(:call).with([non_duplicate_notification])
    allow(next_step).to receive(:call).with([same_bucket_notification_1, same_bucket_notification_2])
    allow(same_bucket_notification_1).to receive(:check_and_mark_duplication_against).with(same_bucket_notification_2)
    allow(non_duplicate_notification).to receive(:update_business_process_history).with("Handlers::EnrollmentEventReduceHandler")
    allow(same_bucket_notification_1).to receive(:update_business_process_history).with("Handlers::EnrollmentEventReduceHandler")
    allow(same_bucket_notification_2).to receive(:update_business_process_history).with("Handlers::EnrollmentEventReduceHandler")
  end

  it "sends along a bucket with the single enrollment notification" do
    expect(next_step).to receive(:call).with([non_duplicate_notification])
    subject.call(notifications)
  end

  it "sends along a bucket with the same-bucket enrollment notifications" do
    expect(next_step).to receive(:call).with([same_bucket_notification_1, same_bucket_notification_2])
    subject.call(notifications)
  end

  it "updates the business process history of the single bucket enrollment" do
    expect(non_duplicate_notification).to receive(:update_business_process_history).with("Handlers::EnrollmentEventReduceHandler")
    subject.call(notifications)
  end

  it "updates the business process history of the first group bucket enrollment" do
    expect(same_bucket_notification_1).to receive(:update_business_process_history).with("Handlers::EnrollmentEventReduceHandler")
    subject.call(notifications)
  end

  it "updates the business process history of the second group bucket enrollment" do
    expect(same_bucket_notification_2).to receive(:update_business_process_history).with("Handlers::EnrollmentEventReduceHandler")
    subject.call(notifications)
  end
end

describe Handlers::EnrollmentEventReduceHandler, "given a termination event and the policy already terminated", :dbclean => :after_each do
  let(:eg_id) { '1' }
  let(:carrier_id) { '1' }
  let(:active_plan) { Plan.create!(:name => "test_plan", carrier_id: carrier_id, hios_plan_id: 1, :coverage_type => "health", year: Date.today.year) }
  let!(:primary) {
    person = FactoryGirl.create :person
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }
  let(:active_enrollee) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start:  Date.today.beginning_of_year, coverage_end: Date.today.beginning_of_year.next_month.end_of_month)}
  let!(:active_policy) {
    policy =  FactoryGirl.create(:policy, enrollment_group_id: eg_id, carrier_id: carrier_id, plan: active_plan, coverage_start: Date.today.beginning_of_year, coverage_end: Date.today.beginning_of_year.next_month.end_of_month, kind: "individual")
    policy.update_attributes(enrollees: [active_enrollee], hbx_enrollment_ids: ["123"], term_for_np: term_for_np)
    policy.save
    policy
  }

  let(:term_event_xml) { <<-EVENTXML
     <enrollment_event xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='http://openhbx.org/api/terms/1.0'>
     <header>
       <hbx_id>29035</hbx_id>
       <submitted_timestamp>2021-12-08T17:44:49</submitted_timestamp>
     </header>
     <event>
       <body>
         <enrollment_event_body xmlns="http://openhbx.org/api/terms/1.0">
           <enrollment xmlns="http://openhbx.org/api/terms/1.0">
            <type>urn:openhbx:terms:v1:enrollment#terminate_enrollment</type>
             <policy>
               <id>
                 <id>123</id>
               </id>
               <enrollees>
                 <enrollee>
                   <member>
                     <id><id>#{primary.authority_member.hbx_member_id}</id></id>
                   </member>
                   <is_subscriber>true</is_subscriber>
                   <benefit>
                     <premium_amount>111.11</premium_amount>
                     <begin_date>#{Date.today.beginning_of_year.strftime("%Y%m%d")}</begin_date>
                     <end_date>#{Date.today.beginning_of_year.end_of_month.strftime("%Y%m%d")}</end_date>
                   </benefit>
                 </enrollee>
               </enrollees>
             </policy>
           </enrollment>
           </enrollment_event_body>
       </body>
     </event>
   </enrollment_event>
  EVENTXML
  }
  let!(:enrollment_action_issue) do
    ::EnrollmentAction::EnrollmentActionIssue.create(
      :hbx_enrollment_id => '123',
      :hbx_enrollment_vocabulary => term_event_xml.to_s,
      :enrollment_action_uri => "urn:openhbx:terms:v1:enrollment#terminate_enrollment"
    )
  end

  let(:next_step) { double }
  let(:amqp_connection) { double }
  let(:m_tag) { double('m_tag') }
  let(:t_stamp) { double('t_stamp') }
  let(:headers) { double('headers') }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
  let :term_event do
    ::ExternalEvents::EnrollmentEventNotification.new event_responder, m_tag, t_stamp, term_event_xml, headers
  end
  let(:event_broadcaster) do
    instance_double(Amqp::EventBroadcaster)
  end
  subject { Handlers::EnrollmentEventReduceHandler.new(next_step) }

  context "when policy terminated by carrier" do
    let(:term_for_np) { true }
    it "does not go on to the next step" do
      expect(next_step).not_to receive(:call)
      expect(event_responder).to receive(:broadcast_ok_response).with("term_event_processed_by_carrier", term_event_xml.to_s, headers)
      expect(event_responder).to receive(:ack_message).with(m_tag)
      subject.call([term_event])
    end
  end

  context "when policy not terminated by carrier" do
    let(:term_for_np) { false }
    it "does go on to the next step" do
      expect(next_step).to receive(:call)
      subject.call([term_event])
    end
  end
end
