require "rails_helper"

describe EnrollmentAction::RetroDependentDropToActive, "given an enrollment event set that:
- has three enrollments
- drop dependent retrospectively to current coverage(2022) using retro sep(event1)
- resulted in cancel of current prospective coverage(2022)(event2)
- and also resulted in adjustment of dates to retro coverage(event3)
- events occured with in the year", :dbclean => :after_each do
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

  subject { EnrollmentAction::RetroDependentDropToActive.new(retro_term_event, retro_dep_drop_event, prospective_cancel_event) }

  let(:event_broadcaster) do
    instance_double(Amqp::EventBroadcaster)
  end

  context "#qualifies #persist #publish", :dbclean => :after_each do
    before do
      allow(Amqp::EventBroadcaster).to receive(:with_broadcaster).and_yield(event_broadcaster)
      allow(event_broadcaster).to receive(:broadcast)
    end

    it "should persist and drop dependent on policy for retro action" do
      expect(EnrollmentAction::RetroDependentDropToActive.qualifies?([retro_term_event, prospective_cancel_event, retro_dep_drop_event])).to be_truthy

      expect(active_policy.enrollees.count).to eq 2 #before persist
      expect(subject.persist).to be_truthy
      active_policy.reload
      expect(active_policy.policy_end).to eq nil
      expect(active_policy.enrollees.select {|en| en.active? }.count).to eq 1 #after persist

      expect_any_instance_of(EnrollmentAction::ActionPublishHelper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#change_member_terminate")
      subject.publish
    end
  end
end