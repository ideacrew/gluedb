require "rails_helper"

describe Handlers::EnrollmentEventEnrichHandler, "given an event with a bogus plan year" do
  let(:next_step) { double }
  let(:event) { instance_double(::ExternalEvents::EnrollmentEventNotification, :drop_if_bogus_plan_year! => true, :drop_if_bogus_term! => false) }

  subject { Handlers::EnrollmentEventEnrichHandler.new(next_step) }

  before :each do
    allow(event).to receive(:check_for_bogus_term_against).with([]).and_return(nil)
  end

  it "does not go on to the next step" do
    expect(next_step).not_to receive(:call)
    subject.call([event])
  end
end

describe Handlers::EnrollmentEventEnrichHandler, "given:
- two events
- one which occurs before the other
- the first event is a bogus renewal term" do
  let(:next_step) { double("FRANK") }
  let(:event_1) { instance_double(::ExternalEvents::EnrollmentEventNotification, :drop_if_bogus_plan_year! => false, :drop_if_bogus_term! => false, :drop_if_bogus_renewal_term! => true) }
  let(:event_2) { instance_double(::ExternalEvents::EnrollmentEventNotification, :drop_if_bogus_plan_year! => false, :drop_if_bogus_term! => false, :drop_if_bogus_renewal_term! => false) }
  let(:resolved_action_2) { instance_double(EnrollmentAction::Base) }

  subject { Handlers::EnrollmentEventEnrichHandler.new(next_step) }

  before :each do
    allow(event_1).to receive(:check_for_bogus_term_against).with([event_2]).and_return(nil)
    allow(event_2).to receive(:check_for_bogus_term_against).with([event_1]).and_return(nil)
    allow(event_1).to receive(:edge_for) do |graph,other_event|
      graph.add_edge(event_1, other_event)
    end
    allow(event_2).to receive(:edge_for) do |graph,other_event|
    end
    allow(event_1).to receive(:check_for_bogus_renewal_term_against).with(event_2).and_return(true)
    allow(EnrollmentAction::Base).to receive(:select_action_for).with([event_2]).and_return(resolved_action_2)
    allow(next_step).to receive(:call).with(resolved_action_2)
    allow(resolved_action_2).to receive(:update_business_process_history).with("Handlers::EnrollmentEventEnrichHandler")
  end

  it "calls the next step without the first action" do
    expect(next_step).to receive(:call).with(resolved_action_2)
    subject.call([event_2, event_1])
  end

  it "appends the step to the history of the process" do
    expect(resolved_action_2).to receive(:update_business_process_history).with("Handlers::EnrollmentEventEnrichHandler")
    subject.call([event_2, event_1])
  end

end

describe Handlers::EnrollmentEventEnrichHandler, "given:
- two events
- one which occurs before the other
- events are not adjacent" do
  let(:next_step) { double }
  let(:event_1) { instance_double(::ExternalEvents::EnrollmentEventNotification, :drop_if_bogus_plan_year! => false, :drop_if_bogus_term! => false, :drop_if_bogus_renewal_term! => false) }
  let(:event_2) { instance_double(::ExternalEvents::EnrollmentEventNotification, :drop_if_bogus_plan_year! => false, :drop_if_bogus_term! => false, :drop_if_bogus_renewal_term! => false) }
  let(:resolved_action_1) { instance_double(EnrollmentAction::Base) }
  let(:resolved_action_2) { instance_double(EnrollmentAction::Base) }

  subject { Handlers::EnrollmentEventEnrichHandler.new(next_step) }

  before :each do
    allow(event_1).to receive(:check_for_bogus_term_against).with([event_2]).and_return(nil)
    allow(event_2).to receive(:check_for_bogus_term_against).with([event_1]).and_return(nil)
    allow(event_1).to receive(:edge_for) do |graph,other_event|
      graph.add_edge(event_1, other_event)
    end
    allow(event_2).to receive(:edge_for) do |graph,other_event|
    end
    allow(event_1).to receive(:check_for_bogus_renewal_term_against).with(event_2).and_return(false)
    allow(event_1).to receive(:is_adjacent_to?).with(event_2).and_return(false)
    allow(EnrollmentAction::Base).to receive(:select_action_for).with([event_2]).and_return(resolved_action_2)
    allow(EnrollmentAction::Base).to receive(:select_action_for).with([event_1]).and_return(resolved_action_1)
    allow(resolved_action_1).to receive(:update_business_process_history).with("Handlers::EnrollmentEventEnrichHandler")
    allow(resolved_action_2).to receive(:update_business_process_history).with("Handlers::EnrollmentEventEnrichHandler")
    allow(next_step).to receive(:call).with(resolved_action_1)
    allow(next_step).to receive(:call).with(resolved_action_2)
  end

  it "calls the next step with the events properly ordered" do
    expect(next_step).to receive(:call).with(resolved_action_1)
    expect(next_step).to receive(:call).with(resolved_action_2)
    subject.call([event_2, event_1])
  end

  it "appends the step to the history of the first action" do
    expect(resolved_action_1).to receive(:update_business_process_history).with("Handlers::EnrollmentEventEnrichHandler")
    subject.call([event_2, event_1])
  end

  it "appends the step to the history of the second action" do
    expect(resolved_action_2).to receive(:update_business_process_history).with("Handlers::EnrollmentEventEnrichHandler")
    subject.call([event_2, event_1])
  end

end

describe Handlers::EnrollmentEventEnrichHandler, "given:
- two events
- one which occurs before the other
- events are adjacent" do
  let(:next_step) { double }
  let(:event_1) { instance_double(::ExternalEvents::EnrollmentEventNotification, :drop_if_bogus_plan_year! => false, :drop_if_bogus_term! => false, :drop_if_bogus_renewal_term! => false) }
  let(:event_2) { instance_double(::ExternalEvents::EnrollmentEventNotification, :drop_if_bogus_plan_year! => false, :drop_if_bogus_term! => false, :drop_if_bogus_renewal_term! => false) }
  let(:resolved_action_1) { instance_double(EnrollmentAction::Base) }

  subject { Handlers::EnrollmentEventEnrichHandler.new(next_step) }

  before :each do
    allow(event_1).to receive(:check_for_bogus_term_against).with([event_2]).and_return(nil)
    allow(event_2).to receive(:check_for_bogus_term_against).with([event_1]).and_return(nil)
    allow(event_1).to receive(:edge_for) do |graph,other_event|
      graph.add_edge(event_1, other_event)
    end
    allow(event_2).to receive(:edge_for) do |graph,other_event|
    end
    allow(event_1).to receive(:check_for_bogus_renewal_term_against).with(event_2).and_return(false)
    allow(event_1).to receive(:is_adjacent_to?).with(event_2).and_return(true)
    allow(EnrollmentAction::Base).to receive(:select_action_for).with([event_1, event_2]).and_return(resolved_action_1)
    allow(resolved_action_1).to receive(:update_business_process_history).with("Handlers::EnrollmentEventEnrichHandler")
    allow(next_step).to receive(:call).with(resolved_action_1)
  end

  it "searches for the correct action using both events in the correct order" do
    expect(EnrollmentAction::Base).to receive(:select_action_for).with([event_1, event_2]).and_return(resolved_action_1)
    subject.call([event_2, event_1])
  end

  it "calls the next step with the resolved action" do
    expect(next_step).to receive(:call).with(resolved_action_1)
    subject.call([event_2, event_1])
  end

  it "appends the step to the history of the action" do
    expect(resolved_action_1).to receive(:update_business_process_history).with("Handlers::EnrollmentEventEnrichHandler")
    subject.call([event_2, event_1])
  end
end

describe "events with in the year" do
  describe Handlers::EnrollmentEventEnrichHandler, "given:
  - three events, with in current year
  - added dependent retrospectively to current coverage(2022) using retro sep(event1)
  - resulted in cancel of current prospective coverage(2022)(event2)
  - and also resulted in adjustment of dates to retro coverage(event3)
  - events occured in sequence with in the year
  - events are adjacent" do
    let(:eg_id) { '1' }
    let(:carrier_id) { '1' }
    let(:active_plan) { Plan.create!(:name => "test_plan", carrier_id: carrier_id, hios_plan_id: 1, :coverage_type => "health", year: Date.today.year) }
    let!(:primary) {
      person = FactoryGirl.create :person
      person.update(authority_member_id: person.members.first.hbx_member_id)
      person
    }
    let!(:dep) {
      person = FactoryGirl.create :person
      person.update(authority_member_id: person.members.first.hbx_member_id)
      person
    }
    let(:active_enrollee) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start:  Date.today.beginning_of_year, coverage_end: '')}
    let!(:active_policy) {
      policy =  FactoryGirl.create(:policy, enrollment_group_id: eg_id, carrier_id: carrier_id, plan: active_plan, coverage_start: Date.today.beginning_of_year, coverage_end: nil, kind: kind)
      policy.update_attributes(enrollees: [active_enrollee], hbx_enrollment_ids: ["123", "456"])
      policy.save
      policy
    }
    let(:retro_term_date) { Date.today.beginning_of_year.end_of_month }
    let(:retro_dep_add_date) { Date.today.beginning_of_year.next_month }
    let(:prospective_cancel_date) { (Date.today.beginning_of_year.+ 3.months).next_month }

    let(:retro_term_event_xml) { <<-EVENTXML
     <enrollment_event xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='http://openhbx.org/api/terms/1.0'>
     <header>
       <hbx_id>29035</hbx_id>
       <submitted_timestamp>2021-12-08T17:44:49</submitted_timestamp>
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
                 <begin_date>#{Date.today.beginning_of_year.strftime("%Y%m%d")}</begin_date>
                 <end_date>#{retro_term_date.strftime("%Y%m%d")}</end_date>
               </benefit>
             </affected_member>
           </affected_members>
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
                   <end_date>#{retro_term_date.strftime("%Y%m%d")}</end_date>
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
                   <id>#{carrier_id}</id>
                 </id>
                 <name>CareFirst</name>
               </carrier>
               <metal_level>urn:openhbx:terms:v1:plan_metal_level#platinum</metal_level>
               <coverage_type>urn:openhbx:terms:v1:qhp_benefit_coverage#health</coverage_type>
               <ehb_percent>99.64</ehb_percent>
             </plan>
             <individual_market>
               <assistance_effective_date>TOTALLY BOGUS</assistance_effective_date>
               <applied_aptc_amount>100.00</applied_aptc_amount>
             </individual_market>
             <premium_total_amount>56.78</premium_total_amount>
             <total_responsible_amount>123.45</total_responsible_amount>
             </enrollment>
             </policy>
           </enrollment>
           </enrollment_event_body>
       </body>
     </event>
   </enrollment_event>
    EVENTXML
    }
    let(:retro_dep_add_event_xml) { <<-EVENTXML
     <enrollment_event xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='http://openhbx.org/api/terms/1.0'>
     <header>
       <hbx_id>29035</hbx_id>
       <submitted_timestamp>2022-05-08T17:44:49</submitted_timestamp>
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
                 <begin_date>#{retro_dep_add_date.strftime("%Y%m%d")}</begin_date>
               </benefit>
             </affected_member>
             <affected_member>
               <member>
                 <id><id>#{dep.authority_member.hbx_member_id}</id></id>
               </member>
               <benefit>
                 <premium_amount>465.13</premium_amount>
                 <begin_date>#{retro_dep_add_date.strftime("%Y%m%d")}</begin_date>
               </benefit>
             </affected_member>
           </affected_members>
           <enrollment xmlns="http://openhbx.org/api/terms/1.0">
             <type>urn:openhbx:terms:v1:enrollment#initial</type>
             <policy>
               <id>
                 <id>789</id>
               </id>
               <enrollees>
                 <enrollee>
                   <member>
                     <id><id>#{primary.authority_member.hbx_member_id}</id></id>
                   </member>
                   <is_subscriber>true</is_subscriber>
                   <benefit>
                     <premium_amount>111.11</premium_amount>
                     <begin_date>#{retro_dep_add_date.strftime("%Y%m%d")}</begin_date>
                   </benefit>
                 </enrollee>
                <enrollee>
                 <member>
                   <id><id>#{dep.authority_member.hbx_member_id}</id></id>
                 </member>
                 <is_subscriber>false</is_subscriber>
                 <benefit>
                   <premium_amount>111.11</premium_amount>
                   <begin_date>#{retro_dep_add_date.strftime("%Y%m%d")}</begin_date>
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
                     <id>#{carrier_id}</id>
                   </id>
                   <name>CareFirst</name>
                 </carrier>
                 <metal_level>urn:openhbx:terms:v1:plan_metal_level#platinum</metal_level>
                 <coverage_type>urn:openhbx:terms:v1:qhp_benefit_coverage#health</coverage_type>
                 <ehb_percent>99.64</ehb_percent>
               </plan>
               <individual_market>
                 <assistance_effective_date>TOTALLY BOGUS</assistance_effective_date>
                 <applied_aptc_amount>100.00</applied_aptc_amount>
                 </individual_market>
               <premium_total_amount>56.78</premium_total_amount>
               <total_responsible_amount>123.45</total_responsible_amount>
               </enrollment>
               <is_active>true</is_active>
             </policy>
           </enrollment>
           </enrollment_event_body>
       </body>
     </event>
   </enrollment_event>
    EVENTXML
    }
    let(:prospective_cancel_event_xml) { <<-EVENTXML
     <enrollment_event xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='http://openhbx.org/api/terms/1.0'>
     <header>
       <hbx_id>29035</hbx_id>
       <submitted_timestamp>2022-04-08T17:44:49</submitted_timestamp>
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
                 <begin_date>#{prospective_cancel_date.strftime("%Y%m%d")}</begin_date>
                 <end_date>#{prospective_cancel_date.strftime("%Y%m%d")}</end_date>
               </benefit>
             </affected_member>
           </affected_members>
           <enrollment xmlns="http://openhbx.org/api/terms/1.0">
            <type>urn:openhbx:terms:v1:enrollment#terminate_enrollment</type>
             <policy>
               <id>
                 <id>456</id>
               </id>
             <enrollees>
               <enrollee>
                 <member>
                   <id><id>#{primary.authority_member.hbx_member_id}</id></id>
                 </member>
                 <is_subscriber>true</is_subscriber>
                 <benefit>
                   <premium_amount>111.11</premium_amount>
                   <begin_date>#{prospective_cancel_date.strftime("%Y%m%d")}</begin_date>
                   <end_date>#{prospective_cancel_date.strftime("%Y%m%d")}</end_date>
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
                   <id>#{carrier_id}</id>
                 </id>
                 <name>CareFirst</name>
               </carrier>
               <metal_level>urn:openhbx:terms:v1:plan_metal_level#platinum</metal_level>
               <coverage_type>urn:openhbx:terms:v1:qhp_benefit_coverage#health</coverage_type>
               <ehb_percent>99.64</ehb_percent>
             </plan>
             <individual_market>
               <assistance_effective_date>TOTALLY BOGUS</assistance_effective_date>
               <applied_aptc_amount>100.00</applied_aptc_amount>
             </individual_market>
             <premium_total_amount>56.78</premium_total_amount>
             <total_responsible_amount>123.45</total_responsible_amount>
             </enrollment>
             </policy>
           </enrollment>
           </enrollment_event_body>
       </body>
     </event>
   </enrollment_event>
    EVENTXML
    }
    let(:kind) { 'individual' }
    let(:amqp_connection) { double }
    let(:m_tag) { double('m_tag') }
    let(:t_stamp) { double('t_stamp') }
    let(:headers) { double('headers') }
    let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
    let :retro_term_event do
      ::ExternalEvents::EnrollmentEventNotification.new event_responder, m_tag, t_stamp, retro_term_event_xml, headers
    end
    let :prospective_cancel_event do
      ::ExternalEvents::EnrollmentEventNotification.new event_responder, m_tag, t_stamp, prospective_cancel_event_xml, headers
    end
    let :retro_dep_add_event do
      ::ExternalEvents::EnrollmentEventNotification.new event_responder, m_tag, t_stamp, retro_dep_add_event_xml, headers
    end

    let(:app) do
      Proc.new do |context|
        context
      end
    end
    let(:resolved_action) { EnrollmentAction::Base.select_action_for([retro_term_event, prospective_cancel_event, retro_dep_add_event]) }
    subject { Handlers::EnrollmentEventEnrichHandler.new(app) }

    it "searches for the correct action using both events in the correct order" do
      expect(EnrollmentAction::Base).to receive(:select_action_for).with([retro_term_event, prospective_cancel_event, retro_dep_add_event]).and_return(resolved_action)
      subject.call([retro_dep_add_event, retro_term_event, prospective_cancel_event])
    end

    it "calls the next step with the resolved action" do
      expect(app).to receive(:call).with(an_instance_of(EnrollmentAction::RetroDependentAddToActive))
      subject.call([retro_dep_add_event, retro_term_event, prospective_cancel_event])
    end

    it "appends the step to the history of the action" do
      expect_any_instance_of(EnrollmentAction::RetroDependentAddToActive).to receive(:update_business_process_history).with("Handlers::EnrollmentEventEnrichHandler")
      subject.call([retro_dep_add_event, retro_term_event, prospective_cancel_event])
    end
  end
end

describe "events with in the year" do
  describe Handlers::EnrollmentEventEnrichHandler, "given:
  - three events, with in current year
  - drop dependent retrospectively to current coverage(2022) using retro sep(event1)
  - resulted in cancel of current prospective coverage(2022)(event2)
  - and also resulted in adjustment of dates to retro coverage(event3)
  - events occured in sequence with in the year
  - events are adjacent" do
    let(:eg_id) { '1' }
    let(:carrier_id) { '1' }
    let(:active_plan) { Plan.create!(:name => "test_plan", carrier_id: carrier_id, hios_plan_id: 1, :coverage_type => "health", year: Date.today.year) }
    let!(:primary) {
      person = FactoryGirl.create :person
      person.update(authority_member_id: person.members.first.hbx_member_id)
      person
    }
    let!(:dep) {
      person = FactoryGirl.create :person
      person.update(authority_member_id: person.members.first.hbx_member_id)
      person
    }
    let(:active_enrollee) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start:  Date.today.beginning_of_year, coverage_end: '')}
    let(:dep_enrollee) { Enrollee.new(m_id: dep.authority_member.hbx_member_id, rel_code: 'child', coverage_start: Date.today.beginning_of_year, coverage_end: '')}
    let!(:active_policy) {
      policy =  FactoryGirl.create(:policy, enrollment_group_id: eg_id, carrier_id: carrier_id, plan: active_plan, coverage_start: Date.today.beginning_of_year, coverage_end: nil, kind: kind)
      policy.update_attributes(enrollees: [active_enrollee, dep_enrollee], hbx_enrollment_ids: ["123", "456"])
      policy.save
      policy
    }
    let(:retro_term_date) { Date.today.beginning_of_year.end_of_month }
    let(:retro_dep_drop_date) { Date.today.beginning_of_year.next_month }
    let(:prospective_cancel_date) { (Date.today.beginning_of_year.+ 3.months).next_month }

    let(:retro_term_event_xml) { <<-EVENTXML
     <enrollment_event xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='http://openhbx.org/api/terms/1.0'>
     <header>
       <hbx_id>29035</hbx_id>
       <submitted_timestamp>2021-12-08T17:44:49</submitted_timestamp>
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
                 <begin_date>#{Date.today.beginning_of_year.strftime("%Y%m%d")}</begin_date>
                 <end_date>#{retro_term_date.strftime("%Y%m%d")}</end_date>
               </benefit>
             </affected_member>
             <affected_member>
               <member>
                 <id><id>#{dep.authority_member.hbx_member_id}</id></id>
               </member>
               <benefit>
                 <premium_amount>465.13</premium_amount>
                 <begin_date>#{Date.today.beginning_of_year.strftime("%Y%m%d")}</begin_date>
                  <end_date>#{retro_term_date.strftime("%Y%m%d")}</end_date>
               </benefit>
             </affected_member>
           </affected_members>
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
                   <end_date>#{retro_term_date.strftime("%Y%m%d")}</end_date>
                 </benefit>
               </enrollee>
               <enrollee>
                 <member>
                   <id><id>#{dep.authority_member.hbx_member_id}</id></id>
                 </member>
                 <is_subscriber>false</is_subscriber>
                 <benefit>
                   <premium_amount>111.11</premium_amount>
                   <begin_date>#{Date.today.beginning_of_year.strftime("%Y%m%d")}</begin_date>
                   <end_date>#{retro_term_date.strftime("%Y%m%d")}</end_date>
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
                   <id>#{carrier_id}</id>
                 </id>
                 <name>CareFirst</name>
               </carrier>
               <metal_level>urn:openhbx:terms:v1:plan_metal_level#platinum</metal_level>
               <coverage_type>urn:openhbx:terms:v1:qhp_benefit_coverage#health</coverage_type>
               <ehb_percent>99.64</ehb_percent>
             </plan>
             <individual_market>
               <assistance_effective_date>TOTALLY BOGUS</assistance_effective_date>
               <applied_aptc_amount>100.00</applied_aptc_amount>
             </individual_market>
             <premium_total_amount>56.78</premium_total_amount>
             <total_responsible_amount>123.45</total_responsible_amount>
             </enrollment>
             </policy>
           </enrollment>
           </enrollment_event_body>
       </body>
     </event>
   </enrollment_event>
    EVENTXML
    }
    let(:retro_dep_drop_event_xml) { <<-EVENTXML
     <enrollment_event xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='http://openhbx.org/api/terms/1.0'>
     <header>
       <hbx_id>29035</hbx_id>
       <submitted_timestamp>2022-05-08T17:44:49</submitted_timestamp>
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
                 <begin_date>#{retro_dep_drop_date.strftime("%Y%m%d")}</begin_date>
               </benefit>
             </affected_member>
           </affected_members>
           <enrollment xmlns="http://openhbx.org/api/terms/1.0">
             <type>urn:openhbx:terms:v1:enrollment#initial</type>
             <policy>
               <id>
                 <id>789</id>
               </id>
               <enrollees>
                 <enrollee>
                   <member>
                     <id><id>#{primary.authority_member.hbx_member_id}</id></id>
                   </member>
                   <is_subscriber>true</is_subscriber>
                   <benefit>
                     <premium_amount>111.11</premium_amount>
                     <begin_date>#{retro_dep_drop_date.strftime("%Y%m%d")}</begin_date>
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
                     <id>#{carrier_id}</id>
                   </id>
                   <name>CareFirst</name>
                 </carrier>
                 <metal_level>urn:openhbx:terms:v1:plan_metal_level#platinum</metal_level>
                 <coverage_type>urn:openhbx:terms:v1:qhp_benefit_coverage#health</coverage_type>
                 <ehb_percent>99.64</ehb_percent>
               </plan>
               <individual_market>
                 <assistance_effective_date>TOTALLY BOGUS</assistance_effective_date>
                 <applied_aptc_amount>100.00</applied_aptc_amount>
                 </individual_market>
               <premium_total_amount>56.78</premium_total_amount>
               <total_responsible_amount>123.45</total_responsible_amount>
               </enrollment>
               <is_active>true</is_active>
             </policy>
           </enrollment>
           </enrollment_event_body>
       </body>
     </event>
   </enrollment_event>
    EVENTXML
    }
    let(:prospective_cancel_event_xml) { <<-EVENTXML
     <enrollment_event xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='http://openhbx.org/api/terms/1.0'>
     <header>
       <hbx_id>29035</hbx_id>
       <submitted_timestamp>2022-04-08T17:44:49</submitted_timestamp>
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
                 <begin_date>#{prospective_cancel_date.strftime("%Y%m%d")}</begin_date>
                 <end_date>#{prospective_cancel_date.strftime("%Y%m%d")}</end_date>
               </benefit>
             </affected_member>
             <affected_member>
               <member>
                 <id><id>#{dep.authority_member.hbx_member_id}</id></id>
               </member>
               <benefit>
                 <premium_amount>465.13</premium_amount>
                 <begin_date>#{prospective_cancel_date.strftime("%Y%m%d")}</begin_date>
                 <end_date>#{prospective_cancel_date.strftime("%Y%m%d")}</end_date>
               </benefit>
             </affected_member>
           </affected_members>
           <enrollment xmlns="http://openhbx.org/api/terms/1.0">
            <type>urn:openhbx:terms:v1:enrollment#terminate_enrollment</type>
             <policy>
               <id>
                 <id>456</id>
               </id>
             <enrollees>
               <enrollee>
                 <member>
                   <id><id>#{primary.authority_member.hbx_member_id}</id></id>
                 </member>
                 <is_subscriber>true</is_subscriber>
                 <benefit>
                   <premium_amount>111.11</premium_amount>
                   <begin_date>#{prospective_cancel_date.strftime("%Y%m%d")}</begin_date>
                   <end_date>#{prospective_cancel_date.strftime("%Y%m%d")}</end_date>
                 </benefit>
               </enrollee>
               <enrollee>
                 <member>
                   <id><id>#{dep.authority_member.hbx_member_id}</id></id>
                 </member>
                 <is_subscriber>false</is_subscriber>
                 <benefit>
                   <premium_amount>111.11</premium_amount>
                   <begin_date>#{prospective_cancel_date.strftime("%Y%m%d")}</begin_date>
                   <end_date>#{prospective_cancel_date.strftime("%Y%m%d")}</end_date>
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
                   <id>#{carrier_id}</id>
                 </id>
                 <name>CareFirst</name>
               </carrier>
               <metal_level>urn:openhbx:terms:v1:plan_metal_level#platinum</metal_level>
               <coverage_type>urn:openhbx:terms:v1:qhp_benefit_coverage#health</coverage_type>
               <ehb_percent>99.64</ehb_percent>
             </plan>
             <individual_market>
               <assistance_effective_date>TOTALLY BOGUS</assistance_effective_date>
               <applied_aptc_amount>100.00</applied_aptc_amount>
             </individual_market>
             <premium_total_amount>56.78</premium_total_amount>
             <total_responsible_amount>123.45</total_responsible_amount>
             </enrollment>
             </policy>
           </enrollment>
           </enrollment_event_body>
       </body>
     </event>
   </enrollment_event>
    EVENTXML
    }
    let(:kind) { 'individual' }
    let(:amqp_connection) { double }
    let(:m_tag) { double('m_tag') }
    let(:t_stamp) { double('t_stamp') }
    let(:headers) { double('headers') }
    let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
    let :retro_term_event do
      ::ExternalEvents::EnrollmentEventNotification.new event_responder, m_tag, t_stamp, retro_term_event_xml, headers
    end
    let :prospective_cancel_event do
      ::ExternalEvents::EnrollmentEventNotification.new event_responder, m_tag, t_stamp, prospective_cancel_event_xml, headers
    end
    let :retro_dep_drop_event do
      ::ExternalEvents::EnrollmentEventNotification.new event_responder, m_tag, t_stamp, retro_dep_drop_event_xml, headers
    end

    let(:app) do
      Proc.new do |context|
        context
      end
    end
    let(:resolved_action) { EnrollmentAction::Base.select_action_for([retro_term_event, prospective_cancel_event, retro_dep_drop_event]) }
    subject { Handlers::EnrollmentEventEnrichHandler.new(app) }

    it "searches for the correct action using both events in the correct order" do
      expect(EnrollmentAction::Base).to receive(:select_action_for).with([retro_term_event, prospective_cancel_event, retro_dep_drop_event]).and_return(resolved_action)
      subject.call([retro_dep_drop_event, retro_term_event, prospective_cancel_event])
    end

    it "calls the next step with the resolved action" do
      expect(app).to receive(:call).with(an_instance_of(EnrollmentAction::RetroDependentDropToActive))
      subject.call([retro_dep_drop_event, retro_term_event, prospective_cancel_event])
    end

    it "appends the step to the history of the action" do
      expect_any_instance_of(EnrollmentAction::RetroDependentDropToActive).to receive(:update_business_process_history).with("Handlers::EnrollmentEventEnrichHandler")
      subject.call([retro_dep_drop_event, retro_term_event, prospective_cancel_event])
    end
  end
end

describe "events with in the year" do
  describe Handlers::EnrollmentEventEnrichHandler, "given:
  - three events, with in current year
  - assistance change(APTC) retrospectively to current coverage(2022) using retro sep(event1)
  - resulted in cancel of current prospective coverage(2022)(event2)
  - and also resulted in adjustment of dates to retro coverage(event3)
  - events occured in sequence with in the year
  - events are adjacent" do
    let(:eg_id) { '1' }
    let(:carrier_id) { '1' }
    let(:active_plan) { Plan.create!(:name => "test_plan", carrier_id: carrier_id, hios_plan_id: 1, :coverage_type => "health", year: Date.today.year) }
    let!(:primary) {
      person = FactoryGirl.create :person
      person.update(authority_member_id: person.members.first.hbx_member_id)
      person
    }
    let(:active_enrollee) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start:  Date.today.beginning_of_year, coverage_end: '')}
    let!(:active_policy) {
      policy =  FactoryGirl.create(:policy, enrollment_group_id: eg_id, carrier_id: carrier_id, plan: active_plan, coverage_start: Date.today.beginning_of_year, coverage_end: nil, kind: kind)
      policy.update_attributes(enrollees: [active_enrollee], hbx_enrollment_ids: ["123", "456"])
      policy.save
      policy
    }
    let(:retro_term_date) { Date.today.beginning_of_year.end_of_month }
    let(:retro_aptc_change_date) { Date.today.beginning_of_year.next_month }
    let(:prospective_cancel_date) { (Date.today.beginning_of_year.+ 3.months).next_month }

    let(:retro_term_event_xml) { <<-EVENTXML
     <enrollment_event xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='http://openhbx.org/api/terms/1.0'>
     <header>
       <hbx_id>29035</hbx_id>
       <submitted_timestamp>2021-12-08T17:44:49</submitted_timestamp>
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
                 <begin_date>#{Date.today.beginning_of_year.strftime("%Y%m%d")}</begin_date>
                 <end_date>#{retro_term_date.strftime("%Y%m%d")}</end_date>
               </benefit>
             </affected_member>
           </affected_members>
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
                   <end_date>#{retro_term_date.strftime("%Y%m%d")}</end_date>
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
                   <id>#{carrier_id}</id>
                 </id>
                 <name>CareFirst</name>
               </carrier>
               <metal_level>urn:openhbx:terms:v1:plan_metal_level#platinum</metal_level>
               <coverage_type>urn:openhbx:terms:v1:qhp_benefit_coverage#health</coverage_type>
               <ehb_percent>99.64</ehb_percent>
             </plan>
             <individual_market>
               <assistance_effective_date>#{Date.today.beginning_of_year.strftime("%Y%m%d")}</assistance_effective_date>
               <applied_aptc_amount>100.00</applied_aptc_amount>
             </individual_market>
             <premium_total_amount>56.78</premium_total_amount>
             <total_responsible_amount>123.45</total_responsible_amount>
             </enrollment>
             </policy>
           </enrollment>
           </enrollment_event_body>
       </body>
     </event>
   </enrollment_event>
    EVENTXML
    }
    let(:retro_aptc_change_event_xml) { <<-EVENTXML
     <enrollment_event xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='http://openhbx.org/api/terms/1.0'>
     <header>
       <hbx_id>29035</hbx_id>
       <submitted_timestamp>2022-05-08T17:44:49</submitted_timestamp>
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
                 <begin_date>#{retro_aptc_change_date.strftime("%Y%m%d")}</begin_date>
               </benefit>
             </affected_member>
           </affected_members>
           <enrollment xmlns="http://openhbx.org/api/terms/1.0">
             <type>urn:openhbx:terms:v1:enrollment#initial</type>
             <policy>
               <id>
                 <id>789</id>
               </id>
               <enrollees>
                 <enrollee>
                   <member>
                     <id><id>#{primary.authority_member.hbx_member_id}</id></id>
                   </member>
                   <is_subscriber>true</is_subscriber>
                   <benefit>
                     <premium_amount>111.11</premium_amount>
                     <begin_date>#{retro_aptc_change_date.strftime("%Y%m%d")}</begin_date>
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
                     <id>#{carrier_id}</id>
                   </id>
                   <name>CareFirst</name>
                 </carrier>
                 <metal_level>urn:openhbx:terms:v1:plan_metal_level#platinum</metal_level>
                 <coverage_type>urn:openhbx:terms:v1:qhp_benefit_coverage#health</coverage_type>
                 <ehb_percent>99.64</ehb_percent>
               </plan>
               <individual_market>
                 <assistance_effective_date>#{retro_aptc_change_date.strftime("%Y%m%d")}</assistance_effective_date>
                 <applied_aptc_amount>50.00</applied_aptc_amount>
                 </individual_market>
               <premium_total_amount>56.78</premium_total_amount>
               <total_responsible_amount>123.45</total_responsible_amount>
               </enrollment>
               <is_active>true</is_active>
             </policy>
           </enrollment>
           </enrollment_event_body>
       </body>
     </event>
   </enrollment_event>
    EVENTXML
    }
    let(:prospective_cancel_event_xml) { <<-EVENTXML
     <enrollment_event xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='http://openhbx.org/api/terms/1.0'>
     <header>
       <hbx_id>29035</hbx_id>
       <submitted_timestamp>2022-04-08T17:44:49</submitted_timestamp>
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
                 <begin_date>#{prospective_cancel_date.strftime("%Y%m%d")}</begin_date>
                 <end_date>#{prospective_cancel_date.strftime("%Y%m%d")}</end_date>
               </benefit>
             </affected_member>
           </affected_members>
           <enrollment xmlns="http://openhbx.org/api/terms/1.0">
            <type>urn:openhbx:terms:v1:enrollment#terminate_enrollment</type>
             <policy>
               <id>
                 <id>456</id>
               </id>
             <enrollees>
               <enrollee>
                 <member>
                   <id><id>#{primary.authority_member.hbx_member_id}</id></id>
                 </member>
                 <is_subscriber>true</is_subscriber>
                 <benefit>
                   <premium_amount>111.11</premium_amount>
                   <begin_date>#{prospective_cancel_date.strftime("%Y%m%d")}</begin_date>
                   <end_date>#{prospective_cancel_date.strftime("%Y%m%d")}</end_date>
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
                   <id>#{carrier_id}</id>
                 </id>
                 <name>CareFirst</name>
               </carrier>
               <metal_level>urn:openhbx:terms:v1:plan_metal_level#platinum</metal_level>
               <coverage_type>urn:openhbx:terms:v1:qhp_benefit_coverage#health</coverage_type>
               <ehb_percent>99.64</ehb_percent>
             </plan>
             <individual_market>
               <assistance_effective_date>#{prospective_cancel_date.strftime("%Y%m%d")}</assistance_effective_date>
               <applied_aptc_amount>100.00</applied_aptc_amount>
             </individual_market>
             <premium_total_amount>56.78</premium_total_amount>
             <total_responsible_amount>123.45</total_responsible_amount>
             </enrollment>
             </policy>
           </enrollment>
           </enrollment_event_body>
       </body>
     </event>
   </enrollment_event>
    EVENTXML
    }
    let(:kind) { 'individual' }
    let(:amqp_connection) { double }
    let(:m_tag) { double('m_tag') }
    let(:t_stamp) { double('t_stamp') }
    let(:headers) { double('headers') }
    let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
    let :retro_term_event do
      ::ExternalEvents::EnrollmentEventNotification.new event_responder, m_tag, t_stamp, retro_term_event_xml, headers
    end
    let :prospective_cancel_event do
      ::ExternalEvents::EnrollmentEventNotification.new event_responder, m_tag, t_stamp, prospective_cancel_event_xml, headers
    end
    let :retro_aptc_change_event do
      ::ExternalEvents::EnrollmentEventNotification.new event_responder, m_tag, t_stamp, retro_aptc_change_event_xml, headers
    end

    let(:app) do
      Proc.new do |context|
        context
      end
    end
    let(:resolved_action) { EnrollmentAction::Base.select_action_for([retro_term_event, prospective_cancel_event, retro_aptc_change_event]) }
    subject { Handlers::EnrollmentEventEnrichHandler.new(app) }

    it "searches for the correct action using both events in the correct order" do
      expect(EnrollmentAction::Base).to receive(:select_action_for).with([retro_term_event, prospective_cancel_event, retro_aptc_change_event]).and_return(resolved_action)
      subject.call([retro_aptc_change_event, retro_term_event, prospective_cancel_event])
    end

    it "calls the next step with the resolved action" do
      expect(app).to receive(:call).with(an_instance_of(EnrollmentAction::RetroAssistanceChangeToActive))
      subject.call([retro_aptc_change_event, retro_term_event, prospective_cancel_event])
    end

    it "appends the step to the history of the action" do
      expect_any_instance_of(EnrollmentAction::RetroAssistanceChangeToActive).to receive(:update_business_process_history).with("Handlers::EnrollmentEventEnrichHandler")
      subject.call([retro_aptc_change_event, retro_term_event, prospective_cancel_event])
    end
  end
end