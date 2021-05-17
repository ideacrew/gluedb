require "rails_helper"

describe EnrollmentAction::MemberIdentifierEnricher do
  let(:xml_ns) do
    { :cv => "http://openhbx.org/api/terms/1.0" }
  end

  let(:member_id_ns) { "urn:openhbx:hbx:me0:resources:v1:person:member_id#" }
  let(:policy_id_ns) { "urn:openhbx:hbx:me0:resources:v1:person:policy_id#" }

  let(:xml) do
    File.open(
      File.join(
       File.dirname(__FILE__),
       "..",
       "..",
       "data",
       "ivl_enrollment_example.xml"
      )
    )
  end

  let(:doc) { Nokogiri::XML(xml) }

  let(:enrollee) do
    instance_double(
      Enrollee,
      m_id: member_id,
      c_id: carrier_member_id,
      cp_id: carrier_policy_id
    )
  end

  let(:member_id) { "19794808" }
  let(:carrier_member_id) { "A CARRIER MEMBER ID" }
  let(:carrier_policy_id) { "A CARRIER POLICY ID" }

  let(:expected_carrier_member_id) do
    member_id_ns +
      carrier_member_id
  end

  let(:expected_carrier_policy_id) do
    policy_id_ns +
      carrier_policy_id
  end

  subject { EnrollmentAction::MemberIdentifierEnricher.new(doc) }

  it "assigns the carrier member id" do
    subject.set_carrier_assigned_member_id_for(enrollee)
    affected_member_node = doc.at_xpath(
      "//cv:affected_members/cv:affected_member/cv:member/" +
        "cv:id/cv:id[contains(text(), '#{member_id}')]/../" +
        "cv:alias_ids/cv:alias_id/cv:id[contains(text(), '#{member_id_ns}')]",
      xml_ns
    )
   member_node = doc.at_xpath(
      "//cv:enrollment_event_body/cv:enrollment/cv:policy/" + 
      "cv:enrollees/cv:enrollee/cv:member/" +
        "cv:id/cv:id[contains(text(), '#{member_id}')]/../" +
        "cv:alias_ids/cv:alias_id/cv:id[contains(text(), '#{member_id_ns}')]",
      xml_ns
    )
    expect(affected_member_node.content).to eq expected_carrier_member_id
    expect(member_node.content).to eq expected_carrier_member_id
  end

  it "assigns the carrier policy id" do
    subject.set_carrier_assigned_policy_id_for(enrollee)
    affected_member_node = doc.at_xpath(
      "//cv:affected_members/cv:affected_member/cv:member/" +
        "cv:id/cv:id[contains(text(), '#{member_id}')]/../" +
        "cv:alias_ids/cv:alias_id/cv:id[contains(text(), '#{policy_id_ns}')]",
      xml_ns
    )
   member_node = doc.at_xpath(
      "//cv:enrollment_event_body/cv:enrollment/cv:policy/" + 
      "cv:enrollees/cv:enrollee/cv:member/" +
        "cv:id/cv:id[contains(text(), '#{member_id}')]/../" +
        "cv:alias_ids/cv:alias_id/cv:id[contains(text(), '#{policy_id_ns}')]",
      xml_ns
    )
    expect(affected_member_node.content).to eq expected_carrier_policy_id
    expect(member_node.content).to eq expected_carrier_policy_id
  end
end