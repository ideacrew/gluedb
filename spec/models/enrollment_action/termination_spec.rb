require "rails_helper"

describe EnrollmentAction::Termination, "given an EnrollmentAction array that:
  - has one element that is a termination
  - has one element that is not a termination
  - has more than one element 
  - the enrollment is for a carrier who is reinstate capable" do

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, is_termination?: true) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification, is_termination?: false) }

  subject { EnrollmentAction::Termination }

  before :each do
    allow(subject).to receive(:reinstate_capable_carrier?).with(event_1).and_return(true)
    allow(subject).to receive(:reinstate_capable_carrier?).with(event_2).and_return(true)
  end

  it "qualifies" do
    expect(subject.qualifies?([event_1])).to be_truthy
  end

  it "does not qualify" do
    expect(subject.qualifies?([event_2])).to be_false
  end

  it "does not qualify" do
    expect(subject.qualifies?([event_1, event_2])).to be_false
  end

  context "
  - has one element that is a termination
  - the enrollment is for a carrier who is not reinstate capable
  " do

    it "does not qualify" do
      allow(subject).to receive(:reinstate_capable_carrier?).with(event_1).and_return(false)
      expect(subject.qualifies?([event_1])).to be_false
    end
  end
end

describe EnrollmentAction::Termination, "given a valid shop enrollment" do
  let(:member) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:enrollee) { instance_double(::Openhbx::Cv2::Enrollee, member: member) }
  let(:terminated_policy_cv) { instance_double(Openhbx::Cv2::Policy, enrollees: [enrollee])}
  let(:carrier) { instance_double(Carrier, :termination_cancels_renewal => false) }
  let(:policy) { instance_double(Policy, hbx_enrollment_ids: [1], policy_end: (Date.today - 1.day), is_shop?: true, :carrier => carrier, reload: true, canceled?: false) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    policy_cv: terminated_policy_cv,
    existing_policy: policy,
    all_member_ids: [1,2]
    ) }

  before :each do
    allow(policy).to receive(:term_for_np).and_return(false)
    allow(termination_event.existing_policy).to receive(:terminate_as_of).and_return(true)
    allow(termination_event).to receive(:subscriber_end).and_return(false)
    allow(termination_event).to receive(:is_cancel?).and_return(false)
    allow(Observers::PolicyUpdated).to receive(:notify).with(policy)
  end

  subject do
    EnrollmentAction::Termination.new(termination_event, nil)
  end

  it "notifies of the termination" do
    expect(Observers::PolicyUpdated).to receive(:notify).with(policy)
    subject.persist
  end

  it "persists" do
    expect(subject.persist).to be_truthy
  end
end

describe EnrollmentAction::Termination, "given a valid IVL enrollment, ending 12/31" do
  let(:member) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:enrollee) { instance_double(::Openhbx::Cv2::Enrollee, member: member) }
  let(:terminated_policy_cv) { instance_double(Openhbx::Cv2::Policy, enrollees: [enrollee])}
  let(:carrier) { instance_double(Carrier, :termination_cancels_renewal => false) }
  let(:policy) { instance_double(Policy, hbx_enrollment_ids: [1], policy_end: ((Date.today - 1.day)), is_shop?: false, :carrier => carrier, reload: true, canceled?: false) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    policy_cv: terminated_policy_cv,
    existing_policy: policy,
    all_member_ids: [1,2]
    ) }

  before :each do
    allow(policy).to receive(:term_for_np).and_return(false)
    allow(policy).to receive(:terminate_as_of).and_return(true)
    allow(termination_event).to receive(:is_cancel?).and_return(false)
    allow(termination_event).to receive(:subscriber_end).and_return(Date.new(Date.today.year, 12, 31))
    allow(Observers::PolicyUpdated).to receive(:notify).with(policy)
  end

  subject do
    EnrollmentAction::Termination.new(termination_event, nil)
  end

  it "does not notify of the termination" do
    expect(Observers::PolicyUpdated).not_to receive(:notify).with(policy)
    subject.persist
  end

  it "persists" do
    expect(subject.persist).to be_truthy
  end
end

describe EnrollmentAction::Termination, "given a valid IVL enrollment, ending 12/31, but with an npt change" do
  let(:member) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:enrollee) { instance_double(::Openhbx::Cv2::Enrollee, member: member) }
  let(:terminated_policy_cv) { instance_double(Openhbx::Cv2::Policy, enrollees: [enrollee])}
  let(:carrier) { instance_double(Carrier, :termination_cancels_renewal => false) }
  let(:policy) { instance_double(Policy, hbx_enrollment_ids: [1], policy_end: ((Date.today - 1.day)), is_shop?: false, carrier: carrier, reload: true, canceled?: false) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    policy_cv: terminated_policy_cv,
    existing_policy: policy,
    all_member_ids: [1,2]
    ) }

  before :each do
    allow(policy).to receive(:term_for_np).and_return(true, false)
    allow(policy).to receive(:terminate_as_of).and_return(true)
    allow(termination_event).to receive(:is_cancel?).and_return(false)
    allow(termination_event).to receive(:subscriber_end).and_return(Date.new(Date.today.year, 12, 31))
    allow(Observers::PolicyUpdated).to receive(:notify).with(policy)
  end

  subject do
    EnrollmentAction::Termination.new(termination_event, nil)
  end

  it "notifies of the termination" do
    expect(Observers::PolicyUpdated).to receive(:notify).with(policy)
    subject.persist
  end

  it "persists" do
    expect(subject.persist).to be_truthy
  end
end

describe EnrollmentAction::Termination, "given an valid IVL enrollment, cancel event with subscriber start date in past" do
  let(:member) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:enrollee) { instance_double(::Openhbx::Cv2::Enrollee, member: member) }
  let(:terminated_policy_cv) { instance_double(Openhbx::Cv2::Policy, enrollees: [enrollee])}
  let(:carrier) { Carrier.create }
  let(:policy) { FactoryGirl.create(:policy, hbx_enrollment_ids: [1], carrier: carrier) }
  let(:start_date) { Date.new(Date.today.year) }
  let(:term_date) { start_date + 1.month}
  let(:termination_event) { instance_double(
      ::ExternalEvents::EnrollmentEventNotification,
      policy_cv: terminated_policy_cv,
      existing_policy: policy,
      subscriber_start: term_date,
      subscriber_end: term_date,
      all_member_ids: [1,2]
  ) }

  before :each do
    policy.enrollees.update_all(coverage_start: start_date, coverage_end: nil)
    allow(policy).to receive(:term_for_np).and_return(true, false)
    allow(termination_event).to receive(:is_cancel?).and_return(true)
    allow(Observers::PolicyUpdated).to receive(:notify).with(policy)
  end

  subject do
    EnrollmentAction::Termination.new(termination_event, nil)
  end

  it "should terminate policy with correct date" do
    expect(subject.persist).to be_truthy
    expect(policy.reload.policy_end).to eq (term_date - 1.day)
  end
end

describe EnrollmentAction::Termination, "given a valid enrollment" do
  let(:amqp_connection) { double }
  let(:event_xml) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, connection: amqp_connection) }
  let(:enrollee) { double(m_id: 1, coverage_start: :one_month_ago, :c_id => nil, :cp_id => nil, coverage_end: :one_month_ago) }
  let(:carrier) { instance_double(Carrier, :termination_cancels_renewal => false) }
  let(:policy) { instance_double(Policy, id: 1, enrollees: [enrollee], eg_id: 1, aasm_state: "submitted", employer_id: '', carrier: carrier, reload: true, canceled?: false) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    event_xml: event_xml,
    existing_policy: policy,
    all_member_ids: [enrollee.m_id],
    event_responder: event_responder,
    hbx_enrollment_id: 1,
    employer_hbx_id: 1
  ) }
  let(:action_helper_result_xml) { double }
  let(:action_publish_helper) { instance_double(
    EnrollmentAction::ActionPublishHelper,
    to_xml: action_helper_result_xml
  ) }

  before :each do
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).and_return(action_publish_helper)
    allow(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
    allow(action_publish_helper).to receive(:set_policy_id).with(policy.id)
    allow(action_publish_helper).to receive(:set_member_starts).with({1 => enrollee.coverage_start})
    allow(action_publish_helper).to receive(:set_member_end_date).with({ 1 => enrollee.coverage_end })
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, termination_event.hbx_enrollment_id, termination_event.employer_hbx_id)
  end

  subject do
    EnrollmentAction::Termination.new(termination_event, nil)
  end

  it "publishes a termination event" do
    expect(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
    subject.publish
  end

  it "sets policy id" do
    expect(action_publish_helper).to receive(:set_policy_id).with(1)
    subject.publish
  end

  it "sets member start" do
    expect(action_publish_helper).to receive(:set_member_starts).with({1 => enrollee.coverage_start})
    subject.publish
  end

  it "sets member end" do
    expect(action_publish_helper).to receive(:set_member_end_date).with({1 => enrollee.coverage_end})
    subject.publish
  end

  it "publishes resulting xml to edi" do
    expect(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, termination_event.hbx_enrollment_id, termination_event.employer_hbx_id)
    subject.publish
  end
end

describe "Given IVL Policy CV with dependent drop", :dbclean => :after_each do
  let(:amqp_connection) { double }
  let(:event_xml) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
  let(:eg_id) { '1' }
  let(:carrier_id) { '2' }
  let(:kind) { 'individual' }

  let(:applied_aptc_amount) { 50.0 }
  let(:premium_total_amount) { 100.0 }
  let(:total_responsible_amount) { 50.0 }
  let(:carrier) { Carrier.create }
  let(:active_plan) { Plan.create!(:name => "test_plan", carrier_id: carrier_id, :coverage_type => "health", year: Date.today.year) }
  let!(:primary) {
    person = FactoryGirl.create :person
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }

  let(:coverage_start) { Date.today.beginning_of_year }
  let(:coverage_end) { Date.today.beginning_of_year.end_of_month }
  let(:active_enrollee1) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start: Date.today.beginning_of_year, coverage_end: '', :c_id => nil, :cp_id => nil)}

  let!(:active_policy) {
    policy =  Policy.create(enrollment_group_id: eg_id, hbx_enrollment_ids: ["123"], carrier_id: carrier_id, plan: active_plan, carrier: carrier, coverage_start: Date.today.beginning_of_year, coverage_end: nil, kind: kind)
    policy.update_attributes(enrollees: [active_enrollee1],
                             pre_amt_tot: premium_total_amount,
                             tot_res_amt: total_responsible_amount,
                             applied_aptc: applied_aptc_amount,
                             hbx_enrollment_ids: ["123"])
    policy.aptc_credits.create!(start_on: Date.today.beginning_of_year, end_on: Date.new(2022,12,31), pre_amt_tot: premium_total_amount, tot_res_amt: total_responsible_amount, aptc: applied_aptc_amount)
    policy.save
    policy
  }

  let(:termination_xml) { <<-EVENTXML
   <enrollment_event xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='http://openhbx.org/api/terms/1.0'>
   <header>
     <hbx_id>29035</hbx_id>
     <submitted_timestamp>2016-11-08T17:44:49</submitted_timestamp>
   </header>
   <event>
     <body>
       <enrollment_event_body xmlns="http://openhbx.org/api/terms/1.0">
         <affected_members>
           <affected_member>
             <member>
               <id><id>#{primary.authority_member.hbx_member_id}</id></id>
             </member>
             <benefit>
               <premium_amount>465.13</premium_amount>
               <begin_date>#{coverage_start.strftime("%Y%m%d")}</begin_date>
               <end_date>#{coverage_end.strftime("%Y%m%d")}</end_date>
             </benefit>
           </affected_member>
         </affected_members>
         <enrollment xmlns="http://openhbx.org/api/terms/1.0">
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
                 <begin_date>#{coverage_start.strftime("%Y%m%d")}</begin_date>
                 <end_date>#{coverage_end.strftime("%Y%m%d")}</end_date>
               </benefit>
             </enrollee>          
           </enrollees>
           <enrollment>
            <plan>
               <id>
                  <id>#{active_plan.hios_plan_id}</id>
               </id>
               <name>BluePreferred PPO Standard Platinum $0</name>
               <active_year>#{active_plan.year}</active_year>
               <is_dental_only>false</is_dental_only>
               <carrier>
                 <id>
                   <id>#{carrier.hbx_carrier_id}</id>
                 </id>
                 <name>CareFirst</name>
               </carrier>
               <metal_level>urn:openhbx:terms:v1:plan_metal_level#platinum</metal_level>
               <coverage_type>urn:openhbx:terms:v1:qhp_benefit_coverage#health</coverage_type>
               <ehb_percent>99.64</ehb_percent>
             </plan>
           <individual_market>
             <assistance_effective_date>#{coverage_start.strftime("%Y%m%d")}</assistance_effective_date>
             <applied_aptc_amount>#{applied_aptc_amount}</applied_aptc_amount>
           </individual_market>
           <premium_total_amount>#{premium_total_amount}</premium_total_amount>
           <total_responsible_amount>#{total_responsible_amount}</total_responsible_amount>
           </enrollment>
           </policy>
         </enrollment>
         </enrollment_event_body>
     </body>
   </event>
 </enrollment_event>
  EVENTXML
  }
  let(:m_tag) { double('m_tag') }
  let(:t_stamp) { double('t_stamp') }
  let(:headers) { double('headers') }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
  let :termination_event do
    ::ExternalEvents::EnrollmentEventNotification.new event_responder, m_tag, t_stamp, termination_xml, headers
  end
  let(:connection) { double }

  subject do
    EnrollmentAction::Termination.new(termination_event, nil)
  end

  it "should terminate policy with correct date and update APTC credits end date" do
    expect(active_policy.aasm_state).to eq "submitted"
    expect(active_policy.aptc_credits.where(start_on: coverage_start, end_on: Date.new(2022,12,31)).count).to eq 1
    expect(subject.persist).to be_truthy
    active_policy.reload
    expect(active_policy.aasm_state).to eq "terminated"
    expect(active_policy.aptc_credits.where(start_on: coverage_start).first.end_on).to eq active_policy.policy_end
  end
end
