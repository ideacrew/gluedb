require "rails_helper"

describe ExternalEvents::ExternalPolicyMemberDrop, "given:
- an IVL policy to change
- an IVL policy cv
- a list of dropped member ids
" do
  let(:dependent_id) { "ABCDEFG" }
  let(:existing_policy_id) { "SOME POLICY ID" }
  let(:existing_policy) { instance_double(Policy, :_id => existing_policy_id, :enrollees => [], :is_shop? => false) }
  let(:dropped_member_ids) { [dependent_id] }

  let(:shop_market) { nil }
  let(:individual_market) { instance_double(::Openhbx::Cv2::PolicyEnrollmentIndividualMarket, applied_aptc_amount: aptc_string_value) }
  let(:policy_enrollment) { instance_double(::Openhbx::Cv2::PolicyEnrollment,
                                            individual_market: individual_market,
                                            shop_market: shop_market,
                                            premium_total_amount: premium_total_string_value,
                                            total_responsible_amount: tot_res_amt_string_value
                                           ) }
  let(:policy_cv) do
    instance_double(
      ::Openhbx::Cv2::Policy,
      :policy_enrollment => policy_enrollment,
      :enrollees => [dropped_enrollee]
    )
  end

  let(:benefit_node) { instance_double(Openhbx::Cv2::EnrolleeBenefit, :end_date => end_date) }
  let(:member_node) { instance_double(Openhbx::Cv2::EnrolleeMember, :id => dependent_id) }
  let(:dropped_enrollee) do
    instance_double(
      Openhbx::Cv2::Enrollee,
      :member => member_node,
      :benefit => benefit_node
    )
  end

  let(:end_date) { "20150531" }

  let(:premium_total_string_value) { "456.78" }
  let(:premium_total_bigdecimal_value) { BigDecimal.new(premium_total_string_value) }
  let(:aptc_string_value) { "123.45" }
  let(:aptc_bigdecimal_value) { BigDecimal.new(aptc_string_value) }
  let(:tot_res_amt_string_value) { "333.33" }
  let(:tot_res_amt_bigdecimal_value) { BigDecimal.new(tot_res_amt_string_value) }

  subject { ExternalEvents::ExternalPolicyMemberDrop.new(existing_policy, policy_cv, dropped_member_ids) }

  it "gets the aptc from the policy_cv" do
    expect(subject.extract_aptc_amount).to eq(aptc_bigdecimal_value)
  end

  it "gets the premium_total from the policy_cv" do
    expect(subject.extract_pre_amt_tot).to eq(premium_total_bigdecimal_value)
  end

  it "gets the total responsible amount from the policy_cv" do
    expect(subject.extract_tot_res_amt).to eq(tot_res_amt_bigdecimal_value)
  end

  describe "instructed to get the totals from a different IVL policy CV" do
    let(:other_shop_market) { nil }
    let(:other_individual_market) { instance_double(::Openhbx::Cv2::PolicyEnrollmentIndividualMarket, applied_aptc_amount: other_aptc_string_value) }
    let(:other_policy_enrollment) { instance_double(::Openhbx::Cv2::PolicyEnrollment,
                                              individual_market: other_individual_market,
                                              shop_market: other_shop_market,
                                              premium_total_amount: other_premium_total_string_value,
                                              total_responsible_amount: other_tot_res_amt_string_value
                                             ) }
    let(:other_policy_cv) { instance_double(::Openhbx::Cv2::Policy, :policy_enrollment => other_policy_enrollment, :enrollees => other_enrollees) }
    let(:other_enrollees) { [other_subscriber] }
    let(:subscriber_member) { instance_double(Openhbx::Cv2::EnrolleeMember, :id => "1") }
    let(:other_subscriber_member) { instance_double(Openhbx::Cv2::EnrolleeMember, :id => "1") }
    let(:dependent_member) { instance_double(Openhbx::Cv2::EnrolleeMember, :id => "2") }
    let(:subscriber) { instance_double(::Openhbx::Cv2::Enrollee, :member => subscriber_member) }
    let(:dependent) { instance_double(::Openhbx::Cv2::Enrollee, :member => dependent_member, :benefit => dependent_benefit) }
    let(:other_subscriber) { instance_double(::Openhbx::Cv2::Enrollee, :member => other_subscriber_member, :benefit => other_subscriber_benefit) }
    let(:other_subscriber_benefit) { instance_double(::Openhbx::Cv2::EnrolleeBenefit, :premium_amount => other_source_subscriber_premium_string_value) }
    let(:dependent_benefit) { instance_double(::Openhbx::Cv2::EnrolleeBenefit, :premium_amount => dependent_premium_string_value) }

    let(:other_source_subscriber_premium_string_value) { "123.37" }
    let(:other_source_subscriber_premium_bigdecimal_value) { BigDecimal.new(other_source_subscriber_premium_string_value) }
    let(:dependent_premium_string_value) { "23.37" }
    let(:dependent_premium_bigdecimal_value) { BigDecimal.new(dependent_premium_string_value) }
    let(:other_premium_total_string_value) { "756.78" }
    let(:other_premium_total_bigdecimal_value) { BigDecimal.new(other_premium_total_string_value) }
    let(:other_aptc_string_value) { "223.45" }
    let(:other_aptc_bigdecimal_value) { BigDecimal.new(other_aptc_string_value) }
    let(:other_tot_res_amt_string_value) { "533.33" }
    let(:other_tot_res_amt_bigdecimal_value) { BigDecimal.new(other_tot_res_amt_string_value) }

    before :each do
      subject.use_totals_from(other_policy_cv)
    end

    it "gets the member premium from the other policy_cv" do
      expect(subject.extract_enrollee_premium(subscriber)).to eq(other_source_subscriber_premium_bigdecimal_value)
    end

    it "falls back to the source document when it can't locate the dependent premium amount" do
      expect(subject.extract_enrollee_premium(dependent)).to eq(dependent_premium_bigdecimal_value)
    end

    it "gets the aptc from the other policy_cv" do
      expect(subject.extract_aptc_amount).to eq(other_aptc_bigdecimal_value)
    end

    it "gets the premium_total from the other policy_cv" do
      expect(subject.extract_pre_amt_tot).to eq(other_premium_total_bigdecimal_value)
    end

    it "gets the total responsible amount from the other policy_cv" do
      expect(subject.extract_tot_res_amt).to eq(other_tot_res_amt_bigdecimal_value)
    end

    context "update aptc" do
      let(:policy) { FactoryGirl.create(:policy, applied_aptc:"200", pre_amt_tot:"300",tot_res_amt:"100") }
      let!(:credit) {policy.aptc_credits.create!(start_on:"1/1/2022", end_on:"12/31/2022", pre_amt_tot:"300", tot_res_amt:"100", aptc:"200")}

      it "updates aptc credits & policy with latest values" do
        policy.enrollees.update_all(coverage_start: Date.new(2022), coverage_end: nil)
        subject  = ExternalEvents::ExternalPolicyMemberDrop.new(policy, policy_cv, dropped_member_ids)
        subject.subscriber_start(Date.new(2022))
        expect(policy.applied_aptc.to_f).to eq(200.0)
        subject.persist
        expect(policy.reload.applied_aptc.to_f).to eq(123.45)
      end
    end
  end

  describe "asked to persist a termination on an IVL policy" do

    before :each do
      allow(Policy).to receive(:find).with(existing_policy_id).and_return(existing_policy)
      allow(existing_policy).to receive(:multi_aptc?).and_return(nil)
      allow(existing_policy).to receive(:update_attributes!).with(
        :pre_amt_tot => premium_total_bigdecimal_value,
        :tot_res_amt => tot_res_amt_bigdecimal_value,
        :applied_aptc => aptc_bigdecimal_value
      ).and_return(true)
      allow(existing_policy).to receive(:set_aptc_effective_on).with(
                                    Date.new(2022),
                                    aptc_bigdecimal_value.to_f,
                                    premium_total_bigdecimal_value.to_f,
                                    tot_res_amt_bigdecimal_value.to_f
                                ).and_return(true)
      allow(existing_policy).to receive(:save!).and_return(true)
    end

    it "notifies" do
      expect(Observers::PolicyUpdated).to receive(:notify).with(existing_policy)
      subject.subscriber_start(Date.new(2022))
      subject.persist
    end
  end

  describe "asked to persist a termination on an IVL policy with a 12/31 end date" do

    let(:end_date) { "20151231" }

    before :each do
      allow(Policy).to receive(:find).with(existing_policy_id).and_return(existing_policy)
      allow(existing_policy).to receive(:multi_aptc?).and_return(nil)
      allow(existing_policy).to receive(:update_attributes!).with(
        :pre_amt_tot => premium_total_bigdecimal_value,
        :tot_res_amt => tot_res_amt_bigdecimal_value,
        :applied_aptc => aptc_bigdecimal_value
      ).and_return(true)
      allow(existing_policy).to receive(:set_aptc_effective_on).with(
                                    Date.new(2022),
                                    aptc_bigdecimal_value.to_f,
                                    premium_total_bigdecimal_value.to_f,
                                    tot_res_amt_bigdecimal_value.to_f
                                ).and_return(true)
      allow(existing_policy).to receive(:save!).and_return(true)
    end

    it "doesn't notify" do
      expect(Observers::PolicyUpdated).not_to receive(:notify).with(existing_policy)
      subject.subscriber_start(Date.new(2022))
      subject.persist
    end
  end
end

describe ExternalEvents::ExternalPolicyMemberDrop, "given:
- a SHOP policy to change
- a SHOP policy cv
- a list of dropped member ids
" do
  let(:existing_policy_id) { "SOME POLICY ID" }
  let(:existing_policy) { instance_double(Policy, :_id => existing_policy_id) }
  let(:dropped_member_ids) { [] }

  let(:individual_market) { nil }
  let(:shop_market) { instance_double(::Openhbx::Cv2::PolicyEnrollmentShopMarket,total_employer_responsible_amount: emp_res_amt_string_value) }
  let(:policy_enrollment) { instance_double(::Openhbx::Cv2::PolicyEnrollment,
                                            individual_market: individual_market,
                                            shop_market: shop_market,
                                            premium_total_amount: premium_total_string_value,
                                            total_responsible_amount: tot_res_amt_string_value
                                           ) }
  let(:policy_cv) { instance_double(::Openhbx::Cv2::Policy, :policy_enrollment => policy_enrollment) }

  let(:premium_total_string_value) { "456.78" }
  let(:premium_total_bigdecimal_value) { BigDecimal.new(premium_total_string_value) }
  let(:emp_res_amt_string_value) { "123.45" }
  let(:emp_res_amt_bigdecimal_value) { BigDecimal.new(emp_res_amt_string_value) }
  let(:tot_res_amt_string_value) { "333.33" }
  let(:tot_res_amt_bigdecimal_value) { BigDecimal.new(tot_res_amt_string_value) }

  subject { ExternalEvents::ExternalPolicyMemberDrop.new(existing_policy, policy_cv, dropped_member_ids) }

  it "gets the employer contribution from the policy_cv" do
    expect(subject.extract_employer_contribution).to eq(emp_res_amt_bigdecimal_value)
  end

  it "gets the premium_total from the policy_cv" do
    expect(subject.extract_pre_amt_tot).to eq(premium_total_bigdecimal_value)
  end

  it "gets the total responsible amount from the policy_cv" do
    expect(subject.extract_tot_res_amt).to eq(tot_res_amt_bigdecimal_value)
  end

  describe "instructed to get the totals from a different SHOP policy CV" do
    let(:other_individual_market) { nil }
    let(:other_shop_market) { instance_double(::Openhbx::Cv2::PolicyEnrollmentShopMarket,total_employer_responsible_amount: other_emp_res_amt_string_value) }
    let(:other_policy_enrollment) { instance_double(::Openhbx::Cv2::PolicyEnrollment,
                                                    individual_market: other_individual_market,
                                                    shop_market: other_shop_market,
                                                    premium_total_amount: other_premium_total_string_value,
                                                    total_responsible_amount: other_tot_res_amt_string_value
                                                   ) }
    let(:other_policy_cv) { instance_double(::Openhbx::Cv2::Policy, :policy_enrollment => other_policy_enrollment) }

    let(:other_premium_total_string_value) { "456.78" }
    let(:other_premium_total_bigdecimal_value) { BigDecimal.new(other_premium_total_string_value) }
    let(:other_emp_res_amt_string_value) { "123.45" }
    let(:other_emp_res_amt_bigdecimal_value) { BigDecimal.new(other_emp_res_amt_string_value) }
    let(:other_tot_res_amt_string_value) { "333.33" }
    let(:other_tot_res_amt_bigdecimal_value) { BigDecimal.new(other_tot_res_amt_string_value) }

    before :each do
      subject.use_totals_from(other_policy_cv)
    end

    it "gets the employer contribution from the other policy_cv" do
      expect(subject.extract_employer_contribution).to eq(other_emp_res_amt_bigdecimal_value)
    end

    it "gets the premium_total from the other_policy_cv" do
      expect(subject.extract_pre_amt_tot).to eq(other_premium_total_bigdecimal_value)
    end

    it "gets the total responsible amount from the other_policy_cv" do
      expect(subject.extract_tot_res_amt).to eq(other_tot_res_amt_bigdecimal_value)
    end
  end
end

describe "Given IVL Policy CV with dependent drop", :dbclean => :after_each do
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

  let(:carrier) { Carrier.create!(:renewal_dependent_drop_transmitted_as_renewal => true) }
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
  let(:dep_coverage_drop_date) { Date.today.beginning_of_year + 2.month }
  let(:active_enrollee1) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start: Date.today.beginning_of_year, coverage_end: '', :c_id => nil, :cp_id => nil)}
  let(:active_enrollee2) { Enrollee.new(m_id: dep.authority_member.hbx_member_id, rel_code: 'child', coverage_start: Date.today.beginning_of_year, coverage_end: '', :c_id => nil, :cp_id => nil)}

  let!(:active_policy) {
    policy =  Policy.create(enrollment_group_id: eg_id, hbx_enrollment_ids: ["123"], carrier_id: carrier_id, plan: active_plan, carrier: carrier, coverage_start: Date.today.beginning_of_year, coverage_end: nil, kind: kind)
    policy.update_attributes(enrollees: [active_enrollee1, active_enrollee2],
                             pre_amt_tot: old_premium_total_amount,
                             tot_res_amt: old_total_responsible_amount,
                             applied_aptc: old_applied_aptc_amount,
                             hbx_enrollment_ids: ["123"])
    policy.aptc_credits.create!(start_on: Date.today.beginning_of_year, end_on: Date.new(2022,12,31), pre_amt_tot: old_premium_total_amount, tot_res_amt: old_total_responsible_amount, aptc: old_applied_aptc_amount)

    policy.save
    policy
  }

  let(:xml_after_dependent_drop) { <<-EVENTXML
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
               <begin_date>#{dep_coverage_drop_date.strftime("%Y%m%d")}</begin_date>
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
                 <begin_date>#{dep_coverage_drop_date.strftime("%Y%m%d")}</begin_date>
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
             <assistance_effective_date>#{dep_coverage_drop_date.strftime("%Y%m%d")}</assistance_effective_date>
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
               <id><id>#{primary.authority_member.hbx_member_id}</id></id>
             </member>
             <benefit>
               <premium_amount>465.13</premium_amount>
               <begin_date>#{prim_coverage_start.strftime("%Y%m%d")}</begin_date>
               <end_date>#{(Date.today.beginning_of_year + 2.month - 1.day).strftime("%Y%m%d")}</end_date>
             </benefit>
           </affected_member>
           <affected_member>
             <member>
               <id><id>#{dep.authority_member.hbx_member_id}</id></id>
             </member>
             <benefit>
               <premium_amount>465.13</premium_amount>
               <begin_date>#{prim_coverage_start.strftime("%Y%m%d")}</begin_date>
               <end_date>#{(Date.today.beginning_of_year + 2.month - 1.day).strftime("%Y%m%d")}</end_date>
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
                 <begin_date>#{prim_coverage_start.strftime("%Y%m%d")}</begin_date>
                 <end_date>#{(Date.today.beginning_of_year + 2.month - 1.day).strftime("%Y%m%d")}</end_date>
               </benefit>
             </enrollee>
             <enrollee>
               <member>
                 <id><id>#{dep.authority_member.hbx_member_id}</id></id>
               </member>
               <is_subscriber>false</is_subscriber>
               <benefit>
                 <premium_amount>111.11</premium_amount>
                  <begin_date>#{prim_coverage_start.strftime("%Y%m%d")}</begin_date>
                  <end_date>#{(Date.today.beginning_of_year + 2.month - 1.day).strftime("%Y%m%d")}</end_date>
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
             <assistance_effective_date>#{prim_coverage_start.strftime("%Y%m%d")}</assistance_effective_date>
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
  let :event_after_dependent_drop do
    ::ExternalEvents::EnrollmentEventNotification.new event_responder, m_tag, t_stamp, xml_after_dependent_drop, headers
  end
  let(:dropped_dependents) do
     termination_event.all_member_ids - event_after_dependent_drop.all_member_ids
  end
  let(:connection) { double }
  subject do
    ExternalEvents::ExternalPolicyMemberDrop.new(termination_event.existing_policy, termination_event.policy_cv, dropped_dependents)
  end

  it "should drop dependent and create APTC Credits" do
    subject.use_totals_from(event_after_dependent_drop.policy_cv)
    subject.subscriber_start(event_after_dependent_drop.subscriber_start)
    subject.member_drop_date(dep_coverage_drop_date - 1.day)

    termination_event.existing_policy.reload
    expect(termination_event.existing_policy.enrollees.count).to eq 2
    expect(termination_event.existing_policy.aptc_credits.count).to eq 1
    expect(termination_event.existing_policy.aptc_credits.where(start_on: prim_coverage_start, end_on: Date.new(2022,12,31)).count).to eq 1

    subject.persist
    termination_event.existing_policy.reload
    expect(termination_event.existing_policy.enrollees.where(coverage_end: nil).count).to eq 1
    expect(termination_event.existing_policy.aptc_credits.count).to eq 2
    expect(termination_event.existing_policy.aptc_credits.where(start_on: prim_coverage_start, end_on: Date.today.beginning_of_year + 2.month - 1.day).count).to eq 1
    expect(termination_event.existing_policy.aptc_credits.where(start_on: dep_coverage_drop_date, end_on: Date.new(2022,12,31)).count).to eq 1
  end
end
