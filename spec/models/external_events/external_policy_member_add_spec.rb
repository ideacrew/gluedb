require "rails_helper"

describe ExternalEvents::ExternalPolicyMemberAdd,  "given:
- an IVL policy to change
- an IVL policy cv
- a list of added member ids
", :dbclean => :after_each do
  let(:amqp_connection) { double }
  let(:event_xml) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
  let(:eg_id) { '1' }
  let(:carrier_id) { '2' }
  let(:kind) { 'individual' }

  let(:new_applied_aptc_amount) { 200.0 }
  let(:new_premium_total_amount) { 300.0 }
  let(:new_total_responsible_amount) { 100.0 }

  let(:old_applied_aptc_amount) { 50.0 }
  let(:old_premium_total_amount) { 100.0 }
  let(:old_total_responsible_amount) { 50.0 }

  let(:carrier) { Carrier.create }
  let(:active_plan) { Plan.create!(:name => "test_plan", carrier_id: carrier_id, :coverage_type => "health", year: Date.today.year) }
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
  let(:prim_coverage_start) { Date.today.beginning_of_year }
  let(:dep_coverage_start) { Date.today.beginning_of_year + 1.month }
  let(:active_enrollee1) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start: Date.today.beginning_of_year, coverage_end: '', :c_id => nil, :cp_id => nil, tobacco_use: 'Y')}
  let!(:active_policy) {
    policy =  FactoryGirl.create(:policy, enrollment_group_id: eg_id, hbx_enrollment_ids: ["123"], carrier_id: carrier_id, plan: active_plan, carrier: carrier, coverage_start: Date.today.beginning_of_year, coverage_end: nil, kind: kind)
    policy.update_attributes(enrollees: [active_enrollee1],
                             pre_amt_tot: old_premium_total_amount,
                             tot_res_amt: old_total_responsible_amount,
                             applied_aptc: old_applied_aptc_amount,
                             hbx_enrollment_ids: ["123"])
    policy.aptc_credits.create!(start_on: Date.today.beginning_of_year, end_on: Date.new(2022,12,31), pre_amt_tot: old_premium_total_amount, tot_res_amt: old_total_responsible_amount, aptc: old_applied_aptc_amount)
    policy.save
    policy
  }

  let(:dependent_add_xml) { <<-EVENTXML
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
             <id><id>1</id></id>
           </member>
           <benefit>
             <premium_amount>465.13</premium_amount>
             <begin_date>20190101</begin_date>
           </benefit>
         </affected_member>
       </affected_members>
       <enrollment xmlns="http://openhbx.org/api/terms/1.0">
         <policy>
           <id>
             <id>1234</id>
           </id>
         <enrollees>
           <enrollee>
             <member>
               <id><id>#{primary.authority_member.hbx_member_id}</id></id>
                <person_health>
                    <is_tobacco_user>true</is_tobacco_user>
                  </person_health>
             </member>
             <is_subscriber>true</is_subscriber>
             <benefit>
               <premium_amount>111.11</premium_amount>
               <begin_date>#{dep_coverage_start.strftime("%Y%m%d")}</begin_date>
             </benefit>
           </enrollee>
           <enrollee>
             <member>
               <id><id>#{dep.authority_member.hbx_member_id}</id></id>
                <person_health>
                    <is_tobacco_user>true</is_tobacco_user>
                  </person_health>
             </member>
             <is_subscriber>false</is_subscriber>
             <benefit>
               <premium_amount>111.11</premium_amount>
               <begin_date>#{dep_coverage_start.strftime("%Y%m%d")}</begin_date>
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
           <assistance_effective_date>#{dep_coverage_start.strftime("%Y%m%d")}</assistance_effective_date>
           <applied_aptc_amount>#{new_applied_aptc_amount}</applied_aptc_amount>
         </individual_market>
         <premium_total_amount>#{new_premium_total_amount}</premium_total_amount>
         <total_responsible_amount>#{new_total_responsible_amount}</total_responsible_amount>
         </enrollment>
         </policy>
       </enrollment>
       </enrollment_event_body>
   </body>
 </event>
</enrollment_event>
  EVENTXML
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
             <id><id>1</id></id>
           </member>
           <benefit>
             <premium_amount>465.13</premium_amount>
             <begin_date>20190101</begin_date>
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
                <person_health>
                    <is_tobacco_user>true</is_tobacco_user>
                  </person_health>
             </member>
             <is_subscriber>true</is_subscriber>
             <benefit>
               <premium_amount>111.11</premium_amount>
               <begin_date>#{Date.today.beginning_of_year.strftime("%Y%m%d")}</begin_date>
               <end_date>#{Date.today.beginning_of_year.strftime("%Y%m%d")}</end_date>
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
           <assistance_effective_date>#{Date.today.beginning_of_year.strftime("%Y%m%d")}</assistance_effective_date>
           <applied_aptc_amount>#{old_applied_aptc_amount}</applied_aptc_amount>
         </individual_market>
         <premium_total_amount>#{old_premium_total_amount}</premium_total_amount>
         <total_responsible_amount>#{old_total_responsible_amount}</total_responsible_amount>
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
  let :dependent_add_event do
    ::ExternalEvents::EnrollmentEventNotification.new event_responder, m_tag, t_stamp, dependent_add_xml, headers
  end
  let(:added_dependents) do
    dependent_add_event.all_member_ids - termination_event.all_member_ids
  end
  subject do
    ExternalEvents::ExternalPolicyMemberAdd.new(termination_event.existing_policy, dependent_add_event.policy_cv, added_dependents)
  end
  let(:connection) { double }

  it "persist tobacco status on new enrollee" do
    subject.subscriber_start(dependent_add_event.subscriber_start)
    termination_event.existing_policy.reload
    expect(termination_event.existing_policy.enrollees.count).to eq 1

    subject.persist
    termination_event.existing_policy.reload
    expect(termination_event.existing_policy.enrollees.count).to eq 2

    # tobacco status persisted on new member added
    new_enrollee = termination_event.existing_policy.enrollees.where(m_id: dep.authority_member.hbx_member_id).first
    expect(new_enrollee.tobacco_use).to eq "Y"
  end
end