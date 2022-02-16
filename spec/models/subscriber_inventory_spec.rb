require "rails_helper"

describe SubscriberInventory do
  describe "given a plan with no matching subscribers" do
    let(:plan) do
      instance_double(
        Plan,
        :_id => "SOME BOGUS ID",
        :hios_plan_id => "FAKEHIOS"
      )
    end

    let(:filters) { { hios_id: plan.hios_plan_id, year: 2015 }}

    it "has no results for #subscriber_ids_for" do
      expect(SubscriberInventory.subscriber_ids_for(filters).to_a).to eq []
    end
  end

  describe "given a plan with matching subscribers", :dbclean => :after_each do
    let(:plan) { FactoryGirl.create(:plan) }
    let(:policy) do
      Policy.create!({
        :enrollees => [
          Enrollee.new({
            "m_id" => "subscriber_id",
            "rel_code" => "self"
          }),
          Enrollee.new({
            "m_id" => "not_subscriber_id",
            "rel_code" => "child"
          })
        ],
        :plan => plan,
        :eg_id => "some eg id"
      })
    end
    let(:filters) { { hios_id: plan.hios_plan_id[0..2], year: plan.year }}

    it "returns the subscriber" do
      policy
      expect(SubscriberInventory.subscriber_ids_for(filters).to_a).to eq ["subscriber_id"]
    end
  end

  describe "given a person with a coverage history" do
    let(:plan) { FactoryGirl.create(:plan) }
    let(:policy) do
      Policy.create!({
        :enrollees => [
          Enrollee.new({
            "m_id" => "subscriber_id",
            "rel_code" => "self"
          }),
          Enrollee.new({
            "m_id" => "not_subscriber_id",
            "rel_code" => "child"
          })
        ],
        :plan => plan,
        :eg_id => "some eg id"
      })
    end

    let(:person) do
      instance_double(
        Person,
        policies: [policy]
      )
    end

    let(:coverage_information_serializer) do
      instance_double(
        Generators::CoverageInformationSerializer,
        process: {}
      )
    end

    it "returns the coverage history in the format ACA Entities expects" do
      expect(Generators::CoverageInformationSerializer).to receive(
        :new
      ).with(person, nil).and_return(coverage_information_serializer)
      expect(SubscriberInventory.coverage_inventory_for(person)).to eq({})
    end
  end
end
