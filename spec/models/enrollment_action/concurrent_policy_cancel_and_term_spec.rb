require "rails_helper"

describe EnrollmentAction::ConcurrentPolicyCancelAndTerm, "given an EnrollmentAction array that:
  - has one element that is a termination and concurrent policy
  - has one element that is a termination and not a concurrent policy
  - has more than one element" do

  let(:subscriber) { Enrollee.new(:m_id=> '1', :coverage_end => nil, :coverage_start => (Date.today - 2.month).beginning_of_month, :rel_code => "self") }
  let(:enrollee) { Enrollee.new(:m_id => "2", :coverage_end => nil, :coverage_start => (Date.today - 1.month).beginning_of_month, :relationship_status_code => "child") }
  let(:policy) { create(:policy, enrollees: [ subscriber, enrollee ]) }
  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, is_termination?: true, is_cancel?: true, existing_policy: policy, subscriber_start: (Date.today - 1.month).beginning_of_month, subscriber_end: (Date.today - 1.month).beginning_of_month, all_member_ids: [1, 2]) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification, is_termination?: false) }

  subject { EnrollmentAction::ConcurrentPolicyCancelAndTerm }

  it "qualifies" do
    expect(subject.qualifies?([event_1])).to be_truthy
  end

  it "does not qualify" do
    expect(subject.qualifies?([event_2])).to be_false
  end

  it "does not qualify" do
    expect(subject.qualifies?([event_1, event_2])).to be_false
  end
end

describe EnrollmentAction::ConcurrentPolicyCancelAndTerm, "given a valid enrollment" do
  let(:member) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:enrollee) { instance_double(::Openhbx::Cv2::Enrollee, member: member) }
  let(:terminated_policy_cv) { instance_double(Openhbx::Cv2::Policy, enrollees: [enrollee])}
  let(:policy) { instance_double(Policy, hbx_enrollment_ids: [1]) }
  let(:termination_event) { instance_double(
      ::ExternalEvents::EnrollmentEventNotification,
      policy_cv: terminated_policy_cv,
      existing_policy: policy,
      all_member_ids: [1,2]
  ) }

  before :each do
    allow(termination_event.existing_policy).to receive(:terminate_as_of).and_return(true)
    allow(termination_event).to receive(:subscriber_end).and_return(Date.today)
  end

  subject do
    EnrollmentAction::ConcurrentPolicyCancelAndTerm.new(termination_event, nil)
  end

  it "persists" do
    expect(subject.persist).to be_truthy
  end

  context "when policy not found" do

    let!(:new_termination_event) { instance_double(
        ::ExternalEvents::EnrollmentEventNotification,
        policy_cv: terminated_policy_cv,
        existing_policy: nil,
        all_member_ids: [1,2]
    ) }

    subject do
      EnrollmentAction::ConcurrentPolicyCancelAndTerm.new(new_termination_event, nil)
    end

    it "return false" do
      expect(subject.persist).to be_false
    end

  end
end

describe EnrollmentAction::ConcurrentPolicyCancelAndTerm, "given a valid enrollment, with concurrent termination" do
  let(:amqp_connection) { double }
  let(:event_xml) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, connection: amqp_connection) }
  let(:enrollee) { double(m_id: 1, coverage_start: 1.month.ago.beginning_of_month, coverage_end: 1.month.since.end_of_month, :c_id => nil, :cp_id => nil) }
  let(:policy) { instance_double(Policy, id: 1, enrollees: [enrollee], eg_id: 1) }
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

  let(:termination_action_publish_helper) { instance_double(
      EnrollmentAction::ActionPublishHelper,
      to_xml: action_helper_result_xml
  ) }

  before :each do
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).and_return(termination_action_publish_helper)
    allow(termination_action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
    allow(termination_action_publish_helper).to receive(:set_policy_id).with(policy.id)
    allow(termination_action_publish_helper).to receive(:set_member_starts).with({1 => enrollee.coverage_start})
    allow(termination_action_publish_helper).to receive(:set_member_end_date).with({1 => enrollee.coverage_end})
    allow(termination_action_publish_helper).to receive(:filter_affected_members).with([enrollee.m_id])
    allow(termination_action_publish_helper).to receive(:filter_enrollee_members).with([enrollee.m_id])
    allow(termination_action_publish_helper).to receive(:recalculate_premium_totals_excluding_dropped_dependents).with([enrollee.m_id])
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, termination_event.hbx_enrollment_id, termination_event.employer_hbx_id)
  end

  subject do
    EnrollmentAction::ConcurrentPolicyCancelAndTerm.new(termination_event, nil)
  end

  it "publishes a termination event" do
    expect(termination_action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
    subject.publish
  end

  it "sets policy id" do
    expect(termination_action_publish_helper).to receive(:set_policy_id).with(1)
    subject.publish
  end

  it "sets member start" do
    expect(termination_action_publish_helper).to receive(:set_member_starts).with({1 => enrollee.coverage_start})
    subject.publish
  end

  it "publishes resulting xml to edi" do
    expect(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, termination_event.hbx_enrollment_id, termination_event.employer_hbx_id)
    subject.publish
  end
end


describe EnrollmentAction::ConcurrentPolicyCancelAndTerm, "given a valid enrollment, with concurrent cancel and termination" do
  let(:amqp_connection) { double }
  let(:event_xml) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, connection: amqp_connection) }
  let(:enrollee) { double(m_id: 1, coverage_start: (Date.today - 1.month).beginning_of_month, coverage_end: Date.today.beginning_of_month, :c_id => nil, :cp_id => nil) }
  let(:enrollee2) { double(m_id: 2, coverage_start: Date.today.beginning_of_month, coverage_end: Date.today.beginning_of_month, :c_id => nil, :cp_id => nil) }
  let(:policy) { instance_double(Policy, id: 1, enrollees: [enrollee, enrollee2], eg_id: 1) }
  let(:termination_event) { instance_double(
      ::ExternalEvents::EnrollmentEventNotification,
      event_xml: event_xml,
      existing_policy: policy,
      all_member_ids: [enrollee.m_id, enrollee2.m_id],
      event_responder: event_responder,
      hbx_enrollment_id: 1,
      employer_hbx_id: 1
  ) }



  let(:cancel_action_helper_result_xml) { double }
  let(:termination_action_helper_result_xml) { double }

  let(:cancel_publish_action_helper) { instance_double(
      EnrollmentAction::ActionPublishHelper,
      to_xml: cancel_action_helper_result_xml
  ) }

  let(:termination_publish_action_helper) { instance_double(
      EnrollmentAction::ActionPublishHelper,
      to_xml: termination_action_helper_result_xml
  ) }

  before :each do
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).and_return(cancel_publish_action_helper, termination_publish_action_helper)

    allow(cancel_publish_action_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#change_member_terminate")
    allow(cancel_publish_action_helper).to receive(:set_policy_id).with(policy.id)
    allow(cancel_publish_action_helper).to receive(:set_member_starts).with({1 => enrollee.coverage_start, 2 => enrollee2.coverage_start})
    allow(cancel_publish_action_helper).to receive(:filter_affected_members).with([enrollee2.m_id])
    allow(cancel_publish_action_helper).to receive(:keep_member_ends).with([enrollee2.m_id])
    allow(cancel_publish_action_helper).to receive(:recalculate_premium_totals_excluding_dropped_dependents).with([enrollee2.m_id])
    allow(subject).to receive(:publish_edi).with(amqp_connection, cancel_action_helper_result_xml, termination_event.hbx_enrollment_id, termination_event.employer_hbx_id).and_return([true, {}])


    allow(termination_publish_action_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
    allow(termination_publish_action_helper).to receive(:set_policy_id).with(policy.id)
    allow(termination_publish_action_helper).to receive(:set_member_starts).with({1 => enrollee.coverage_start, 2 => enrollee2.coverage_start})
    allow(termination_publish_action_helper).to receive(:set_member_end_date).with({1 => enrollee.coverage_end, 2 => enrollee2.coverage_end})
    allow(termination_publish_action_helper).to receive(:filter_affected_members).with([enrollee.m_id])
    allow(termination_publish_action_helper).to receive(:filter_enrollee_members).with([enrollee.m_id])
    allow(termination_publish_action_helper).to receive(:recalculate_premium_totals_excluding_dropped_dependents).with([enrollee.m_id])
    allow(subject).to receive(:publish_edi).with(amqp_connection, termination_action_helper_result_xml, termination_event.hbx_enrollment_id, termination_event.employer_hbx_id).and_return([true, {}])
  end

  subject do
    EnrollmentAction::ConcurrentPolicyCancelAndTerm.new(termination_event, nil)
  end


  it "sets event for cancel action helper" do
    expect(cancel_publish_action_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#change_member_terminate")
    subject.publish
  end

  it "sets event for termination action helper" do
    expect(termination_publish_action_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
    subject.publish
  end

  it "sets policy id for cancel action helper" do
    expect(cancel_publish_action_helper).to receive(:set_policy_id).with(1).and_return(true)
    subject.publish
  end

  it "sets policy id for termination action helper" do
    expect(termination_publish_action_helper).to receive(:set_policy_id).with(1).and_return(true)
    subject.publish
  end

  it "sets member start dates for cancel action helper" do
    expect(cancel_publish_action_helper).to receive(:set_member_starts).with({1 => (Date.today - 1.month).beginning_of_month, 2 =>  Date.today.beginning_of_month})
    subject.publish
  end

  it "sets member start dates for termination action helper" do
    expect(termination_publish_action_helper).to receive(:set_member_starts).with({1 => (Date.today - 1.month).beginning_of_month, 2 =>  Date.today.beginning_of_month})
    subject.publish
  end

  it "filter members for cancel action helper" do
    expect(cancel_publish_action_helper).to receive(:filter_affected_members).with([2])
    subject.publish
  end

  it "filter members for termination action helper" do
    expect(termination_publish_action_helper).to receive(:filter_affected_members).with([1])
    subject.publish
  end

  it "clears all member end dates before publishing for cancel action helper " do
    expect(cancel_publish_action_helper).to receive(:keep_member_ends).with([2])
    subject.publish
  end

  it "sets member end dates for termination action helper" do
    expect(termination_publish_action_helper).to receive(:set_member_end_date).with({1 => Date.today.beginning_of_month, 2 =>  Date.today.beginning_of_month})
    subject.publish
  end


  it "recalculate premium for cancel action helper" do
    expect(cancel_publish_action_helper).to receive(:recalculate_premium_totals_excluding_dropped_dependents).with([2])
    subject.publish
  end

  it "recalculate premium for termination action helper" do
    expect(termination_publish_action_helper).to receive(:recalculate_premium_totals_excluding_dropped_dependents).with([1])
    subject.publish
  end

  it "publishes termination & reinstatment resulting xml to edi" do
    expect(subject).to receive(:publish_edi).exactly(2).times
    subject.publish
  end
end

describe "Given IVL Policy CV with concurrent cancel", :dbclean => :after_each do
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

  let(:coverage_start) { Date.today.beginning_of_year.next_month }
  let(:coverage_end) { Date.today.beginning_of_year.next_month }
  let(:active_enrollee1) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start: Date.today.beginning_of_year, coverage_end: '', :c_id => nil, :cp_id => nil)}

  let(:aptc_one_start) { Date.today.beginning_of_year }
  let(:aptc_one_end) { Date.today.beginning_of_year.end_of_month }
  let(:aptc_two_start) { Date.today.beginning_of_year.next_month }
  let(:aptc_two_end) { Date.today.beginning_of_year.end_of_year }

  let!(:active_policy) {
    policy =  Policy.create(enrollment_group_id: eg_id, hbx_enrollment_ids: ["123", "456"], carrier_id: carrier_id, plan: active_plan, carrier: carrier, coverage_start: Date.today.beginning_of_year, coverage_end: nil, kind: kind)
    policy.update_attributes(enrollees: [active_enrollee1],
                             pre_amt_tot: premium_total_amount,
                             tot_res_amt: total_responsible_amount,
                             applied_aptc: applied_aptc_amount,
                             hbx_enrollment_ids: ["123", "456"])
    policy.aptc_credits.create!(start_on: aptc_one_start, end_on: aptc_one_end, pre_amt_tot: premium_total_amount, tot_res_amt: total_responsible_amount, aptc: applied_aptc_amount)
    policy.aptc_credits.create!(start_on: aptc_two_start, end_on: aptc_two_end, pre_amt_tot: premium_total_amount, tot_res_amt: total_responsible_amount, aptc: applied_aptc_amount)
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
    EnrollmentAction::ConcurrentPolicyCancelAndTerm.new(termination_event, nil)
  end

  it "should terminate policy with correct date and delete future APTC credits" do
    expect(active_policy.aasm_state).to eq "submitted"
    expect(active_policy.aptc_credits.where(start_on: aptc_one_start, end_on: aptc_one_end).count).to eq 1
    expect(active_policy.aptc_credits.where(start_on: aptc_two_start, end_on: aptc_two_end).count).to eq 1
    expect(subject.persist).to be_truthy
    active_policy.reload
    expect(active_policy.aasm_state).to eq "terminated"
    expect(active_policy.policy_end).to eq aptc_one_end # terminated with correct end date
    expect(active_policy.aptc_credits.count).to eq 1
    expect(active_policy.aptc_credits.where(start_on: aptc_one_start, end_on: aptc_one_end).count).to eq 1
    expect(active_policy.aptc_credits.where(start_on: aptc_two_start, end_on: aptc_two_end).count).to eq 0 # deleted future aptc credit
  end
end
