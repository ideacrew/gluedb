require 'rails_helper'
RSpec.describe "enrollment_events/_alias_id.xml.haml" do
  describe "rendering alias_id node with carrier_member_id and carrier_policy_id values" do
    let(:policy) { instance_double(Policy, :enrollees => [enrollee_primary], :eg_id => 1) }
    let!(:enrollee) { double(:m_id => 1, :coverage_start => :one_month_ago, :c_id => '123456', :cp_id => '7123456') }
    before :each do
      render :template => "enrollment_events/_alias_id.xml.haml", :locals => {:enrollee => enrollee}
      @doc = Nokogiri::XML.parse(rendered)
    end

    it "expected the carrier_member_id" do
      expect(@doc.xpath('//alias_ids/alias_id[1]/id').first.text).to eq "urn:openhbx:hbx:me0:resources:v1:person:member_id#123456"
    end

    it "expected the carrier_policy_id" do
      expect(@doc.xpath('//alias_ids/alias_id[2]/id').first.text).to eq "urn:openhbx:hbx:me0:resources:v1:person:policy_id#7123456"
    end
  end
end
