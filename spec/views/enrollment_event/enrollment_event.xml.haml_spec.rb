require 'rails_helper'

RSpec.describe "app/views/enrollment_events/_enrollment_event.xml.haml" do

  let(:policy) { double(id: 24, cobra_eligibility_date:Date.today, subscriber: subscriber1, enrollees: [subscriber1], policy_start: policy_start,
                        policy_end: policy_end, plan: plan, eg_id: 212131212, applied_aptc: 0,
                        cobra_eligibility_date: cobra_date,employer: employer, :is_shop? => true,
                        :is_cobra? => true,broker: nil,carrier_specific_plan_id:'',tot_emp_res_amt:0.0, pre_amt_tot:0.0,tot_res_amt:0.0,rating_area:'',employer:employer,composite_rating_tier:'',created_at:Date.today,updated_at:'') }
  let(:plan) { double(carrier: carrier, name:'Care First', metal_level:'01', ehb:'0.0',coverage_type:"health", year:Date.today.year, hios_plan_id: '123121', id: 'a12db3') }
  let(:carrier) { double(name: 'Care First',hbx_carrier_id:'1', id: 'sd8f7s9d8f7')}
  let(:policy_start) { Date.new(2014, 1, 1) }
  let(:policy_end) { Date.new(2014, 12, 31)}
  let(:cobra_date) { Date.new(2016, 12, 31)}
  let(:subscriber1) { double(person: person, relationship_status_code: 'Self', coverage_start: policy_start, pre_amt: 0.0, cp_id:'', c_id:'', coverage_end: policy_end,ben_stat: 'cobra',subscriber?: false, tobacco_use_value: 'N') }

  let(:person) { double(full_name: 'Ann B Mcc', addresses: [address], authority_member: authority_member, authority_member_id:'1',name_first: 'Ann', name_middle: 'B', name_last: 'Mcc', name_sfx: '',name_pfx: '',emails: [],phones: []) }
  let(:authority_member) { double(ssn: '342321212', dob: (Date.today - 20.years), gender: "male", hbx_member_id: '123') }
  let(:address) { double(address_1: 'Wilson Building', address_2: 'Suite 100',address_3: '', city: 'Washington DC', state: 'DC', zip: '20002',address_type: '',zip_extension: nil, location_county_code: nil) }

  let!(:subscriber) {policy.subscriber}
  let(:employer) {FactoryGirl.create(:employer)}
  let(:enrollees) {policy.enrollees}
  let(:affected_member) { double(enrollee: subscriber1,old_name_last:'',old_name_first:'',old_name_middle:'',old_name_pfx:'',old_name_sfx:'',old_ssn:'',old_gender:'',old_dob:'',subscriber?:true) }
  let(:transaction_id) { "123455463456345634563456" }
  let(:event_type) { "urn:openhbx:terms:v1:enrollment#cobra" }

  before(:each) do
    allow(policy).to receive(:has_responsible_person?).and_return(true)
    allow(policy).to receive(:responsible_person).and_return(person)
    allow(affected_member).to receive(:enrollee_person).and_return(person)
    allow(policy).to receive(:plan_id).and_return(plan.id)
    allow(plan).to receive(:carrier_id).and_return(carrier.id)
    render :template => "enrollment_events/_enrollment_event", :locals => {
                                                                          :affected_members => [affected_member],
                                                                          :policy => policy,
                                                                          :enrollees => enrollees,
                                                                          :event_type => event_type,
                                                                          :transaction_id => transaction_id
                                                                      }
    @doc = Nokogiri::HTML(rendered.gsub("\n", ""))
  end
  
  context "cobra enrollment" do
   
   it "should include market type is cobra" do
      expect(@doc.at_xpath('//market').text).to eq "urn:openhbx:terms:v1:aca_marketplace#cobra"
    end

    it "should include cobra event kind and event date in rendered policy" do
      expect(@doc.at_xpath('//cobra_eligibility_date').text).to eq cobra_date.strftime("%Y%m%d")
      end
    end  
  end
