require "rails_helper"

describe EnrollmentAction::RetroAddAndTerm, "given an EnrollmentAction array that:
  - has one element that has retro new coverage
  - has one element that has terminated current coverage" do
  let(:eg_id) { '1' }
  let(:carrier_id) { '1' }
  let(:renewal_plan) { Plan.create!(:name => "test_plan", carrier_id: carrier_id, hios_plan_id: 1, :coverage_type => "health", year: Date.today.next_year.year) }
  let(:active_plan) { Plan.create!(:name => "test_plan", carrier_id: carrier_id, hios_plan_id: 1, renewal_plan: renewal_plan, :coverage_type => "health", year: Date.today.year) }
  let!(:primary) {
    person = FactoryGirl.create :person
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }
  let(:active_enrollee) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start:  Date.today.next_year.beginning_of_year, coverage_end: '')}
  let!(:active_policy) {
    policy =  FactoryGirl.create(:policy, enrollment_group_id: eg_id, carrier_id: carrier_id, plan: renewal_plan, coverage_start: Date.today.next_year.beginning_of_year, coverage_end: nil, kind: kind)
    policy.update_attributes(enrollees: [active_enrollee], hbx_enrollment_ids: ["123"])
    policy.save
    policy
  }
  let(:term_event_xml) { <<-EVENTXML
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
               <begin_date>#{Date.today.next_year.beginning_of_year.strftime("%Y%m%d")}</begin_date>
               <end_date>#{Date.today.next_year.beginning_of_year.strftime("%Y%m%d")}</end_date>
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
                 <begin_date>#{Date.today.next_year.beginning_of_year.strftime("%Y%m%d")}</begin_date>
                 <end_date>#{Date.today.next_year.beginning_of_year.strftime("%Y%m%d")}</end_date>
               </benefit>
             </enrollee>
           </enrollees>
           <enrollment>
           <plan>
             <id>
                <id>#{renewal_plan.hios_plan_id}</id>
             </id>
             <name>BluePreferred PPO Standard Platinum $0</name>
             <active_year>#{renewal_plan.year}</active_year>
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
  let(:retro_event_xml) { <<-EVENTXML
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
               <begin_date>#{Date.today.beginning_of_year.strftime("%Y%m%d")}</begin_date>
             </benefit>
           </affected_member>
         </affected_members>
         <enrollment xmlns="http://openhbx.org/api/terms/1.0">
           <type>urn:openhbx:terms:v1:enrollment#initial</type>
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
                   <begin_date>#{Date.today.beginning_of_year.strftime("%Y%m%d")}</begin_date>
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
  let(:kind) { 'individual' }
  let(:amqp_connection) { double }
  let(:m_tag) { double('m_tag') }
  let(:t_stamp) { double('t_stamp') }
  let(:headers) { double('headers') }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
  let :termination do
    ::ExternalEvents::EnrollmentEventNotification.new event_responder, m_tag, t_stamp, term_event_xml, headers
  end
  let :action do
    ::ExternalEvents::EnrollmentEventNotification.new event_responder, m_tag, t_stamp, retro_event_xml, headers
  end

  context "qualifies", :dbclean => :after_each do

    subject { EnrollmentAction::RetroAddAndTerm }

    it "should return true" do
      expect(subject.qualifies?([action, termination])).to be_truthy
    end
  end

  context "persist", :dbclean => :after_each do

    before do
      Observers::PolicyUpdated.stub(:notify).with(an_instance_of(Policy)) do
        true
      end
      allow(Observers::PolicyUpdated).to receive(:notify).with(active_policy)
    end

    subject do
      EnrollmentAction::RetroAddAndTerm.new(termination, action)
    end

    it "notifies of the termination" do
      expect(Observers::PolicyUpdated).to receive(:notify).with(active_policy)
      subject.persist
    end

    it "should return true" do
      expect(subject.persist).to be_truthy
    end

    it "should terminate current active policy" do
      subject.persist
      policy = Policy.where(hbx_enrollment_ids: termination.hbx_enrollment_id).first
      policy.reload
      expect(policy.hbx_enrollment_ids).to eq(["123"])
      expect(policy.canceled?).to eq(true)
    end

    it "should create retro active policy" do
      subject.persist
      policy = Policy.where(hbx_enrollment_ids: action.hbx_enrollment_id).first
      expect(policy.hbx_enrollment_ids).to eq(["456"])
      expect(policy.policy_end).to eq(nil)
      expect(policy.is_active?).to eq(true)
    end
  end

  context "publish", :dbclean => :after_each do
    let!(:term_action_helper) do
      term_action_helper = EnrollmentAction::ActionPublishHelper.new(termination.event_xml)
      term_action_helper.set_policy_id(active_policy.eg_id)
      term_action_helper
    end

    let!(:retro_action_helper) do
      EnrollmentAction::ActionPublishHelper.new(action.event_xml)
    end

    before :each do
      allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(termination.event_xml).and_return(term_action_helper)
      allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(action.event_xml).and_return(retro_action_helper)

      allow(term_action_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
      allow(term_action_helper).to receive(:set_policy_id).with(active_policy.eg_id)
      allow(term_action_helper).to receive(:set_member_starts).with({active_enrollee.m_id => active_enrollee.coverage_start})

      allow(subject).to receive(:publish_edi).with(amqp_connection, term_action_helper.to_xml, termination.hbx_enrollment_id, termination.employer_hbx_id).and_return([true, {}])

      allow(retro_action_helper).to receive(:keep_member_ends).with([])
      allow(retro_action_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#initial")
      allow(subject).to receive(:publish_edi).with(amqp_connection, retro_action_helper.to_xml, action.hbx_enrollment_id, action.employer_hbx_id).and_return([true, {}])
    end

    subject do
      EnrollmentAction::RetroAddAndTerm.new(termination, action)
    end

    it "sets event for terminate action helper" do
      expect(term_action_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
      subject.publish
    end

    it "sets event for initial action helper" do
      expect(retro_action_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#initial")
      subject.publish
    end

    it "sets policy id for terminate action helper" do
      expect(term_action_helper).to receive(:set_policy_id).with(active_policy.eg_id).and_return(true)
      subject.publish
    end

    it "sets member start dates for terminate action helper" do
      expect(term_action_helper).to receive(:set_member_starts).with({ active_enrollee.m_id => active_enrollee.coverage_start })
      subject.publish
    end


    it "sets keep member ends for initial action helper" do
      expect(retro_action_helper).to receive(:keep_member_ends).with([])
      subject.publish
    end

    it "publishes termination & initial & renewal resulting xml to edi" do
      expect(subject).to receive(:publish_edi).exactly(2).times
      subject.publish
    end
  end
end