require "rails_helper"

describe ChangeSets::PersonAddressChangeSet do
  let(:address_update_result) { true }

  describe "with an address to wipe" do
    let(:initial_address) { instance_double("::Address", :address_type => "home") }
    let(:person) { instance_double("::Person", :save => address_update_result, addresses: [initial_address]) }
    let(:person_resource) { instance_double("::RemoteResources::IndividualResource", :addresses => [], :hbx_member_id => hbx_member_id) }
    let(:policies_to_notify) { [policy_to_notify] }
    let(:policy_to_notify) { instance_double("Policy", :eg_id => policy_hbx_id, :active_member_ids => hbx_member_ids, :is_shop? => true) }
    let(:hbx_member_ids) { [hbx_member_id, hbx_member_id_2] }
    let(:policy_hbx_id) { "some randome_policy id whatevers" }
    let(:hbx_member_id) { "some random member id wahtever" }
    let(:hbx_member_id_2) { "some other, differently random member id wahtever" }
    let(:policy_cv) { "some policy cv data" }
    let(:policy_serializer) { instance_double("::CanonicalVocabulary::MaintenanceSerializer") }
    let(:cv_publisher) { instance_double(::Services::NfpPublisher) }
    let(:address_kind) { "billing" }
    let(:identity_change_transmitter) { instance_double(::ChangeSets::IdentityChangeTransmitter, :publish => nil) }
    let(:affected_member) { instance_double(::BusinessProcesses::AffectedMember) }
    subject { ChangeSets::PersonAddressChangeSet.new(address_kind) }

    before :each do
      allow(::CanonicalVocabulary::MaintenanceSerializer).to receive(:new).with(
        policy_to_notify, "change", "personnel_data", [hbx_member_id], hbx_member_ids
      ).and_return(policy_serializer)
      allow(::BusinessProcesses::AffectedMember).to receive(:new).with(
       { :policy => policy_to_notify, :member_id => hbx_member_id }
      ).and_return(affected_member)
      allow(::ChangeSets::IdentityChangeTransmitter).to receive(:new).with(
        affected_member,
        policy_to_notify,
        "urn:openhbx:terms:v1:enrollment#change_member_communication_numbers"
      ).and_return(identity_change_transmitter)
      allow(policy_serializer).to receive(:serialize).and_return(policy_cv)
      allow(::Services::NfpPublisher).to receive(:new).and_return(cv_publisher)
    end

    it "should update the person" do
      allow(cv_publisher).to receive(:publish).with(true, "#{policy_hbx_id}.xml", policy_cv)
      expect(person).to receive(:remove_address_of).with(address_kind)
      expect(subject.perform_update(person, person_resource, policies_to_notify)).to eq true
    end

    it "should send out policy notifications" do
      expect(cv_publisher).to receive(:publish).with(true, "#{policy_hbx_id}.xml", policy_cv)
      allow(person).to receive(:remove_address_of).with(address_kind)
      subject.perform_update(person, person_resource, policies_to_notify)
    end

  end

  describe "with an updated address" do
    let(:initial_address) { instance_double("::Address", :address_type => "home") }
    let(:person) { instance_double("::Person", :save => address_update_result, addresses: [initial_address]) }
    let(:person_resource) { instance_double("::RemoteResources::IndividualResource", :addresses => [updated_address_resource], :hbx_member_id => hbx_member_id) }
    let(:updated_address_resource) { double(:to_hash => {:address_type => address_kind}, :address_type => address_kind) }
    let(:policies_to_notify) { [policy_to_notify] }
    let(:policy_to_notify) { instance_double("Policy", :eg_id => policy_hbx_id, :active_member_ids => hbx_member_ids, :is_shop? => true) }
    let(:hbx_member_ids) { [hbx_member_id, hbx_member_id_2] }
    let(:policy_hbx_id) { "some randome_policy id whatevers" }
    let(:hbx_member_id) { "some random member id wahtever" }
    let(:hbx_member_id_2) { "some other, differently random member id wahtever" }
    let(:policy_cv) { "some policy cv data" }
    let(:policy_serializer) { instance_double("::CanonicalVocabulary::MaintenanceSerializer") }
    let(:cv_publisher) { instance_double("::Services::CvPublisher") }
    let(:new_address) { double }
    let(:identity_change_transmitter) { instance_double(::ChangeSets::IdentityChangeTransmitter, :publish => nil) }
    let(:affected_member) { instance_double(::BusinessProcesses::AffectedMember) }
    subject { ChangeSets::PersonAddressChangeSet.new(address_kind) }

    before :each do
      allow(::BusinessProcesses::AffectedMember).to receive(:new).with(
       { :policy => policy_to_notify, :member_id => hbx_member_id }
      ).and_return(affected_member)
      allow(::ChangeSets::IdentityChangeTransmitter).to receive(:new).with(
        affected_member,
        policy_to_notify,
        cv_change_reason,
      ).and_return(identity_change_transmitter)
      allow(Address).to receive(:new).with({:address_type => address_kind}).and_return(new_address)
      allow(person).to receive(:set_address).with(new_address)
      allow(initial_address).to receive(:same_location?).with(new_address).and_return(false)
    end

    describe "updating a home address" do
      let(:address_kind) { "home" }
      let(:identity_change_transmitter) { instance_double(::ChangeSets::IdentityChangeTransmitter, :publish => nil) }
      let(:affected_member) { instance_double(::BusinessProcesses::AffectedMember) }
      let(:cv_change_reason) { "urn:openhbx:terms:v1:enrollment#change_member_address" }

      describe "with an invalid new address" do
        let(:address_update_result) { false }
        it "should fail to process the update" do
          expect(subject.perform_update(person, person_resource, policies_to_notify)).to eq false
        end
      end

      describe "with a valid new address" do
        let(:address_update_result) { true }

        before :each do
          allow(::BusinessProcesses::AffectedMember).to receive(:new).with(
            { :policy => policy_to_notify, :member_id => hbx_member_id }
          ).and_return(affected_member)
          allow(::ChangeSets::IdentityChangeTransmitter).to receive(:new).with(
            affected_member,
            policy_to_notify,
            "urn:openhbx:terms:v1:enrollment#change_member_address"
          ).and_return(identity_change_transmitter)
          allow(::CanonicalVocabulary::MaintenanceSerializer).to receive(:new).with(
            policy_to_notify, "change", "change_of_location", [hbx_member_id], hbx_member_ids
          ).and_return(policy_serializer)
          allow(policy_serializer).to receive(:serialize).and_return(policy_cv)
          allow(::Services::NfpPublisher).to receive(:new).and_return(cv_publisher)
        end

        it "should update the person" do
          allow(cv_publisher).to receive(:publish).with(true, "#{policy_hbx_id}.xml", policy_cv)
          expect(subject.perform_update(person, person_resource, policies_to_notify)).to eq true
        end

        it "should send out policy notifications" do
          expect(cv_publisher).to receive(:publish).with(true, "#{policy_hbx_id}.xml", policy_cv)
          subject.perform_update(person, person_resource, policies_to_notify)
        end
      end
    end

    describe "updating a mailing address" do
      let(:address_kind) { "mailing" }
      let(:identity_change_transmitter) { instance_double(::ChangeSets::IdentityChangeTransmitter, :publish => nil) }
      let(:affected_member) { instance_double(::BusinessProcesses::AffectedMember) }
      let(:cv_change_reason) { "urn:openhbx:terms:v1:enrollment#change_member_communication_numbers" }

      describe "with an invalid new address" do
        let(:address_update_result) { false }
        it "should fail to process the update" do
          expect(subject.perform_update(person, person_resource, policies_to_notify)).to eq false
        end
      end

      describe "with a valid new address" do
        let(:address_update_result) { true }

        before :each do
          allow(::BusinessProcesses::AffectedMember).to receive(:new).with(
            { :policy => policy_to_notify, :member_id => hbx_member_id }
          ).and_return(affected_member)
          allow(::ChangeSets::IdentityChangeTransmitter).to receive(:new).with(
            affected_member,
            policy_to_notify,
            cv_change_reason
          ).and_return(identity_change_transmitter)
          allow(::CanonicalVocabulary::MaintenanceSerializer).to receive(:new).with(
            policy_to_notify, "change", "personnel_data", [hbx_member_id], hbx_member_ids
          ).and_return(policy_serializer)
          allow(policy_serializer).to receive(:serialize).and_return(policy_cv)
          allow(::Services::NfpPublisher).to receive(:new).and_return(cv_publisher)
        end

        it "should update the person" do
          allow(cv_publisher).to receive(:publish).with(true, "#{policy_hbx_id}.xml", policy_cv)
          expect(subject.perform_update(person, person_resource, policies_to_notify)).to eq true
        end

        it "should send out policy notifications" do
          expect(cv_publisher).to receive(:publish).with(true, "#{policy_hbx_id}.xml", policy_cv)
          subject.perform_update(person, person_resource, policies_to_notify)
        end
      end
    end
  end

  describe "given an update with no mailing address against a person with no mailing address" do
    let(:address_kind) { "mailing" }
    let(:person) { instance_double("::Person", :addresses => []) }
    let(:person_resource) { instance_double("::RemoteResources::IndividualResource", :addresses => []) }
    subject { ChangeSets::PersonAddressChangeSet.new(address_kind) }
    it "should not be applicable" do
      expect(subject.applicable?(person, person_resource)).to be_falsey
    end
  end

  describe "given a person update with a different home address as the existing record" do
    let(:address_kind) { "home" }
    let(:person) { instance_double("::Person", :addresses => [person_address]) }
    let(:person_resource) { instance_double("::RemoteResources::IndividualResource", :addresses => [person_resource_address]) }
    let(:person_address) { instance_double("::Address", :address_type => address_kind) }
    let(:person_resource_address) { double(:address_kind => address_kind) }
    subject { ChangeSets::PersonAddressChangeSet.new(address_kind) }
    before(:each) do
      allow(person_address).to receive(:match).with(person_resource_address).and_return(false)
    end
    it "should be applicable" do
      expect(subject.applicable?(person, person_resource)).to be_truthy
    end
  end

  describe "given a person update with the same home address as the existing record" do
    let(:address_kind) { "home" }
    let(:person) { instance_double("::Person", :addresses => [person_address]) }
    let(:person_resource) { instance_double("::RemoteResources::IndividualResource", :addresses => [person_resource_address]) }
    let(:person_address) { instance_double("::Address", :address_type => address_kind) }
    let(:person_resource_address) { double(:address_kind => address_kind) }
    subject { ChangeSets::PersonAddressChangeSet.new(address_kind) }
    before(:each) do
      allow(person_address).to receive(:match).with(person_resource_address).and_return(true)
    end
    it "should not be applicable" do
      expect(subject.applicable?(person, person_resource)).to be_falsey
    end
  end

  describe "given person who has a mailing address, and an update to remove that mailing address" do
    let(:address_kind) { "mailing" }
    let(:person) { instance_double("::Person", :addresses => [person_address]) }
    let(:person_resource) { instance_double("::RemoteResources::IndividualResource", :addresses => []) }
    let(:person_address) { instance_double("::Address", :address_type => address_kind) }

    before(:each) do
      allow(person_address).to receive(:match).with(nil).and_return(false)
    end
    subject { ChangeSets::PersonAddressChangeSet.new(address_kind) }
    it "should be applicable" do
      expect(subject.applicable?(person, person_resource)).to be_truthy
    end
  end
end

describe ChangeSets::PersonAddressChangeSet, "given:
- a person with no mailing address, but a home address
- a new mailing address that matches the home address
" do
  let(:home_address) do
    Address.new(
     address_type: "home"
    )
  end
  let(:address_kind) { "mailing" }
  let(:hbx_member_id) { "some random member id wahtever" }
  let(:policies_to_notify) { [policy_to_notify] }
  let(:policy_to_notify) { double }
  let(:person) do
    Person.new(
      addresses: [home_address]
    )
  end
  let(:person_resource) { instance_double("::RemoteResources::IndividualResource", :addresses => [updated_address_resource], :hbx_member_id => hbx_member_id) }
  let(:updated_address_resource) { double(:to_hash => {:address_type => address_kind}, :address_type => address_kind) }

  subject { ChangeSets::PersonAddressChangeSet.new("mailing") }

  before :each do
    allow(person).to receive(:save).and_return(true)
  end

  it "should update the person" do
    expect(subject.perform_update(person, person_resource, policies_to_notify)).to eq true
  end

  it "should not send out policy notifications" do
    expect(::ChangeSets::IdentityChangeTransmitter).not_to receive(:new)
    subject.perform_update(person, person_resource, policies_to_notify)
  end
end

describe ChangeSets::PersonAddressChangeSet, "given:
- a person with a home and mailing address that are the same
- a request to delete the mailing address
" do
  let(:mailing_address) do
    Address.new(
      address_type: "mailing"
    )
  end

  let(:home_address) do
    Address.new(
      address_type: "home"
    )
  end
  let(:address_kind) { "mailing" }
  let(:hbx_member_id) { "some random member id wahtever" }
  let(:policies_to_notify) { [policy_to_notify] }
  let(:policy_to_notify) { double }
  let(:person) do
    Person.new(
      addresses: [home_address, mailing_address]
    )
  end
  let(:person_resource) { instance_double("::RemoteResources::IndividualResource", :addresses => [], :hbx_member_id => hbx_member_id) }

  subject { ChangeSets::PersonAddressChangeSet.new("mailing") }

  before :each do
    allow(person).to receive(:save).and_return(true)
  end

  it "should update the person" do
    expect(subject.perform_update(person, person_resource, policies_to_notify)).to eq true
  end

  it "should not send out policy notifications" do
    expect(::ChangeSets::IdentityChangeTransmitter).not_to receive(:new)
    subject.perform_update(person, person_resource, policies_to_notify)
  end
end

describe ChangeSets::PersonAddressChangeSet, "given:
- a person with a home and mailing address that are NOT the same
- a request to change only the county FIPS code on the mailing address
" do
  let(:mailing_address) do
    Address.new(
      address_type: "mailing",
      location_county_code: "001234"
    )
  end

  let(:home_address) do
    Address.new(
      address_type: "home"
    )
  end
  let(:address_kind) { "mailing" }
  let(:hbx_member_id) { "some random member id wahtever" }
  let(:policies_to_notify) { [policy_to_notify] }
  let(:policy_to_notify) { double }
  let(:person) do
    Person.new(
      addresses: [home_address, mailing_address]
    )
  end
  let(:person_resource) { instance_double("::RemoteResources::IndividualResource", :addresses => [updated_address_resource], :hbx_member_id => hbx_member_id) }
  let(:updated_address_resource) { double(:to_hash => {:address_type => address_kind}, :address_type => address_kind) }

  subject { ChangeSets::PersonAddressChangeSet.new("mailing") }

  before :each do
    allow(person).to receive(:save).and_return(true)
  end

  it "should update the person" do
    expect(subject.perform_update(person, person_resource, policies_to_notify)).to eq true
  end

  it "should not send out policy notifications" do
    expect(::ChangeSets::IdentityChangeTransmitter).not_to receive(:new)
    subject.perform_update(person, person_resource, policies_to_notify)
  end
end