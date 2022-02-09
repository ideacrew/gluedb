require 'rails_helper'

describe Generators::Reports::IrsYearlySerializer, :dbclean => :after_each do

  let(:address)  { FactoryGirl.create(:address, state:"CA", street_1:"test", street_2:"test 2", city: 'city', zip: "12022", street_1:"street 1", street_2: "street 2", person: person) }
  let(:coverage_start) {Date.today.beginning_of_year.prev_year}
  let(:coverage_end) {coverage_start.end_of_year }
  let(:current_year) {Date.today.year}
  let(:enrollee) {policy.enrollees.create!(m_id: person.members.first.hbx_member_id, rel_code: "self", coverage_start: coverage_start, coverage_end: coverage_end) }
  let(:plan) {FactoryGirl.create(:plan, hios_plan_id: "23232323", ehb: 12, carrier: carrier)} 
  let(:carrier) {FactoryGirl.create(:carrier)}  

  let(:params) { {  policy_id: policy.id, type: "new", void_cancelled_policy_ids: [ Moped::BSON::ObjectId.new ] , void_active_policy_ids: [ Moped::BSON::ObjectId.new ], npt: policy.term_for_np, calendar_year: current_year } }
  let(:household) {double(name:"name", ssn:"00000000")}
  let(:options) { { multiple: false, calendar_year: current_year, qhp_type: "assisted", notice_type: 'new'} }
  let(:premium) {double(premium_amount:100, slcsp_premium_amount: 200, aptc_amount:0)}
  let(:monthly_premiums) { [OpenStruct.new({serial: (1), premium_amount: 0.0, premium_amount_slcsp: 0.0, monthly_aptc: 0.0})] }
  let(:settings) {YAML.load(File.read("#{Rails.root}/config/irs_settings.yml")).with_indifferent_access}
  let(:irs_h41_source_sbm_id) {settings[:irs_h41_generation][:irs_h41_source_sbm_id]}
  let(:h41_folder_name)  { "#{irs_h41_source_sbm_id}.DSH.EOYIN.D#{Time.now.strftime('%Y%m%d')[2..-1]}.T#{Time.now.strftime("%H%M%S") + "000"}.P.IN" }

  let(:policy) { FactoryGirl.create(:policy, term_for_np: false, applied_aptc: 0, pre_amt_tot: 123, plan: plan, carrier: carrier) } 

  let(:person) {FactoryGirl.create(:person, authority_member_id: policy.subscriber.m_id)}
  let(:ft_params) {{report_type: "ORIGINAL", batch_id: "1241241", content_file: "00001", record_sequence_number: "010101"}}
  
  before(:each) do
    person.members.each{|member| member.update_attributes!(dob: (Date.today - 21.years))}
    FileUtils.rm_rf(Dir["FEP*"])
    FileUtils.rm_rf(Dir["H41_federal_report"])
    FileUtils.rm_rf(Dir["*.zip"])
    FileUtils.rm_rf(Dir["#{Rails.root}/tmp/irs_notices"])

    policy.enrollees.each{|er|er.update_attributes!(coverage_start: coverage_start, coverage_end: coverage_end)}
    plan.premium_tables.create!(rate_start_date: policy.coverage_period.first,rate_end_date: policy.coverage_period.last, age: ((policy.coverage_period.first.year - 1) -  (Date.today.year - 21.years)), amount:12)
    allow(subject).to receive(:append_report_row).and_return(true)
    policy.federal_transmissions.create!(ft_params)
  end
  

subject { Generators::Reports::IrsYearlySerializer.new(params) }

  describe 'Generating Individual IRS documents as opposed to a yearly batch' do
    
    context '#generate_notice' do
      it 'generates an individual 1095A file' do
        expect(File).not_to exist("#{Rails.root}/tmp/irs_notices/") 
        policy.subscriber.update_attributes!(m_id: person.authority_member_id)
        person.update_attributes(authority_member_id: policy.subscriber.m_id)
        subject.generate_notice
        expect(File).to exist("#{Rails.root}/tmp/irs_notices/") 
        FileUtils.rm_rf(Dir["#{Rails.root}/tmp/irs_notices"])
      end
    end 

    context '#generate_h41' do
      it 'generates a individual h41 file' do
        expect(File).not_to exist("#{h41_folder_name}")
        policy.subscriber.update_attributes!(m_id: person.authority_member_id)
        person.update_attributes(authority_member_id: policy.subscriber.m_id)
        subject.generate_h41
        expect(File).to exist("#{h41_folder_name}")
        expect(File).to exist("#{h41_folder_name}.zip")
        FileUtils.rm_rf(Dir["#{h41_folder_name}"])
        FileUtils.rm_rf(Dir[("H41_federal_report")])
        FileUtils.rm_rf(Dir["*.zip"])
      end
    end
  end
end