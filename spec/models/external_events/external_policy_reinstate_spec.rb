require "rails_helper"

describe ExternalEvents::ExternalPolicyReinstate, "given:
- a shop cv policy object
- an shop existing policy 
" do

  let(:plan_cv) { instance_double(Openhbx::Cv2::PlanLink) }
  let(:shop_market) { instance_double(Openhbx::Cv2::PolicyEnrollmentShopMarket, :total_employer_responsible_amount => tot_emp_res_amt, :cobra_eligibility_date => cobra_start_date_str) }
  let(:policy_enrollment) do
    instance_double(
      Openhbx::Cv2::PolicyEnrollment,
      :shop_market => shop_market,
      :total_responsible_amount => tot_res_amt,
      :premium_total_amount => pre_amt_tot
    )
  end
  let(:policy_cv) { instance_double(Openhbx::Cv2::Policy, :policy_enrollment => policy_enrollment, :enrollees => [enrollee_node], :id => policy_id) }
  let(:policy) { instance_double(Policy, :enrollees => [enrollee], :hbx_enrollment_ids => hbx_enrollment_ids_field_proxy) }
  let(:enrollee_node) { instance_double(Openhbx::Cv2::Enrollee, :member => member_node) }
  let(:member_node) { instance_double(Openhbx::Cv2::EnrolleeMember, :id => subscriber_id) }
  let(:pre_amt_tot) { "123.45" }
  let(:tot_res_amt) { "123.45" }
  let(:cobra_start_date) { Date.new(2017, 2, 1) }
  let(:cobra_start_date_str) { "20170201" }
  let(:tot_emp_res_amt) { "0.00" }
  let(:policy_id) { "a policy id" }
  let(:hbx_enrollment_ids_field_proxy) { double }
  let(:subscriber_id) { "subscriber id" }
  let(:enrollee) { instance_double(Enrollee, :m_id => subscriber_id) }

  subject { ExternalEvents::ExternalPolicyReinstate.new(policy_cv, policy) }

  let(:expected_policy_update_args) do
      {
        :aasm_state => "resubmitted", :term_for_np=>false
      }
  end

  let(:expected_enrollee_update_args) do
      {
        :aasm_state => "submitted"
      }
  end

  before :each do
    allow(policy).to receive(:update_attributes!) do |args|
      expect(args).to eq(expected_policy_update_args)
    end
    allow(enrollee).to receive(:ben_stat=).with("active")
    allow(enrollee).to receive(:emp_stat=).with("active")
    allow(enrollee).to receive(:coverage_end=).with(nil)
    allow(enrollee).to receive(:termed_by_carrier=).with(false)
    allow(enrollee).to receive(:save!)
    allow(hbx_enrollment_ids_field_proxy).to receive(:<<).with(policy_id)
    allow(policy).to receive(:reload)
    allow(policy).to receive(:save!)
    allow(Observers::PolicyUpdated).to receive(:notify).with(policy)
  end

  it "notifies of the update" do
    expect(Observers::PolicyUpdated).to receive(:notify).with(policy)
    subject.persist
  end

  it "updates the policy attributes" do
    expect(policy).to receive(:update_attributes!) do |args|
      expect(args).to eq(expected_policy_update_args)
    end
    subject.persist
  end

  it "sets the enrollment as active" do
    expect(enrollee).to receive(:ben_stat=).with("active")
    expect(enrollee).to receive(:emp_stat=).with("active")
    expect(enrollee).to receive(:coverage_end=).with(nil)
    expect(enrollee).to receive(:save!)
    subject.persist
  end

  it "updates the hbx_enrollment_ids list" do
    expect(hbx_enrollment_ids_field_proxy).to receive(:<<).with(policy_id)
    subject.persist
  end
end

context "Given a new IVL policy CV with APTC", :dbclean => :after_each do
  let(:eg_id) { '1' }
  let(:carrier_id) { '1' }
  let(:kind) { 'individual' }
  let(:carrier) { Carrier.create }
  let(:active_plan) { Plan.create!(:name => "test_plan", carrier_id: carrier_id, :coverage_type => "health", year: Date.today.year) }
  let!(:primary) {
    person = FactoryGirl.create :person
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }
  let(:coverage_start) { Date.today.beginning_of_year }
  let(:coverage_end) { Date.today.beginning_of_year.end_of_month }
  let(:reinstate_date) { coverage_end + 1.day }

  let(:applied_aptc_amount) { 200.0 }
  let(:premium_total_amount) { 300.0 }
  let(:total_responsible_amount) { 100.0 }

  let(:active_enrollee1) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start: coverage_start, coverage_end: coverage_end, :c_id => nil, :cp_id => nil)}
  let!(:active_policy) {
    policy =  FactoryGirl.create(:policy, enrollment_group_id: eg_id, hbx_enrollment_ids: ["1"], carrier_id: carrier_id, plan: active_plan, carrier: carrier, coverage_start: coverage_start, coverage_end: coverage_end, kind: kind)
    policy.update_attributes(enrollees: [active_enrollee1],
                             pre_amt_tot: premium_total_amount,
                             tot_res_amt: total_responsible_amount,
                             applied_aptc: applied_aptc_amount,
                             hbx_enrollment_ids: ["1"])
    policy.aptc_credits.create!(start_on: coverage_start, end_on: coverage_end, pre_amt_tot: premium_total_amount, tot_res_amt: total_responsible_amount, aptc: applied_aptc_amount)
    policy.save
    policy
  }

  let(:source_event_xml) { <<-EVENTXML
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
               <begin_date>#{reinstate_date.strftime("%Y%m%d")}</begin_date>
             </benefit>
           </affected_member>
         </affected_members>
         <enrollment xmlns="http://openhbx.org/api/terms/1.0">
           <policy>
             <id>
               <id>#{eg_id}</id>
             </id>
           <enrollees>
             <enrollee>
               <member>
                 <id><id>#{primary.authority_member.hbx_member_id}</id></id>
               </member>
               <is_subscriber>true</is_subscriber>
               <benefit>
                 <premium_amount>111.11</premium_amount>
                 <begin_date>#{reinstate_date.strftime("%Y%m%d")}</begin_date>
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
             <assistance_effective_date>#{reinstate_date.strftime("%Y%m%d")}</assistance_effective_date>
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
  let(:responder) { instance_double('::ExternalEvents::EventResponder') }
  let :action do
    ::ExternalEvents::EnrollmentEventNotification.new responder, m_tag, t_stamp, source_event_xml, headers
  end

  subject { ExternalEvents::ExternalPolicyReinstate.new(action.policy_cv, action.existing_policy) }

  it "creates new policy on # persist and should extend APTC Credits end to 12/31" do
    expect(Policy.where(:hbx_enrollment_ids => eg_id, aasm_state: "terminated").count).to eq 1

    action.existing_policy.reload
    expect(action.existing_policy.aptc_credits.count).to eq 1
    expect(action.existing_policy.aptc_credits.where(start_on: coverage_start, end_on: Date.today.beginning_of_year.end_of_month).count).to eq 1
    subject.persist
    action.existing_policy.reload

    # policy reinstated
    expect(Policy.where(:hbx_enrollment_ids => eg_id, aasm_state: "resubmitted").count).to eq 1

    # creates aptc credits
    expect(action.existing_policy.aptc_credits.count).to eq 1
    # extends aptc credits end date on reinstate
    expect(action.existing_policy.aptc_credits.where(start_on: coverage_start, end_on: Date.today.end_of_year).count).to eq 1
  end
end
