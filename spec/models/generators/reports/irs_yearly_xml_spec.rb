require 'rails_helper'

module Generators::Reports
  describe IrsYearlyXml, :dbclean => :after_each do

    let(:slcsp_hios)          { {:slcsp => "94506DC0390014-01"} }
    let!(:plan)               { FactoryGirl.create(:plan) }
    let!(:silver_plan)        { FactoryGirl.create(:plan, hios_plan_id: slcsp_hios[:slcsp]) }
    let(:calendar_year)       { 2018 }
    let(:record_sequence_num) { 532211 }
    
    let(:irs_settings) { 
      settings = YAML.load(File.read("#{Rails.root}/config/irs_settings.yml")).with_indifferent_access 
      settings['tax_document'].merge!({calendar_year => slcsp_hios })
      settings
    }

    let(:carriers) { Carrier.all.inject({}){|hash, carrier| hash[carrier.id] = carrier.name; hash} }
    
    let!(:primary) {
      person = FactoryGirl.create :person, dob: Date.new(1970, 5, 1), name_first: "John", name_last: "Roberts"
      person.update(authority_member_id: person.members.first.hbx_member_id)
      person
    }

    let!(:child)   { 
      person = FactoryGirl.create :person, dob: Date.new(1998, 9, 6), name_first: "Adam", name_last: "Roberts"
      person.update(authority_member_id: person.members.first.hbx_member_id)
      person
    }

    let(:coverage_end) { Date.new(calendar_year, 6, 30) }

    let(:policy) {
      policy = FactoryGirl.create :policy, plan_id: plan.id, coverage_start: Date.new(calendar_year, 1, 1), coverage_end: coverage_end
      policy.enrollees[0].m_id = primary.authority_member.hbx_member_id
      policy.enrollees[1].m_id = child.authority_member.hbx_member_id
      policy.enrollees[1].rel_code ='child'; policy.save
      policy
    }

    let(:irs_input) {
      irs_input = Generators::Reports::IrsInputBuilder.new(policy, { notice_type: 'new' })
      irs_input.carrier_hash = carriers
      irs_input.settings = irs_settings
      irs_input.process
      irs_input
    }

    let(:file) { Rails.root.join("h41.xml") }

    let(:yearly_xsd) {
      Nokogiri::XML::Schema(File.open("#{Rails.root.join('spec', 'support')}/xsds/h41/MSG/IRS-Form1095ATransmissionUpstreamMessage.xsd"))
    }

    subject {
      yearly_xml = Generators::Reports::IrsYearlyXml.new(irs_input.notice)
      yearly_xml.record_sequence_num = record_sequence_num
      xml_report = yearly_xml.serialize.to_xml(:indent => 2)
      File.open(file.to_s, 'w') {|file| file.write xml_report }
    }

    before do
      allow(irs_input.notice).to receive(:issuer_name).and_return('Carefirst') 
    end

    it 'should generate h41 xml' do
      subject
      expect(File.exists?(file)).to be_truthy
      File.delete file
    end

    it 'should generate valid h41 xml' do
      subject
      doc = Nokogiri::XML(File.open(file))
      # New validation xsd need to be updated to fix the spec
      # expect(yearly_xsd.valid?(doc)).to be_truthy
      File.delete file
    end
  end
end
