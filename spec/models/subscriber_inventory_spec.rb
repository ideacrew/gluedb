require "rails_helper"

describe SubscriberInventory do
  describe "given a plan with no matching subscribers" do
    let(:plan) { instance_double(Plan, :_id => "SOME BOGUS ID") }

    it "has no results for #subscriber_ids_for" do
      expect(SubscriberInventory.subscriber_ids_for(plan).to_a).to eq []
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

    it "returns the subscriber" do
      policy
      expect(SubscriberInventory.subscriber_ids_for(plan).to_a).to eq ["subscriber_id"]
    end
  end

  describe "given a person with a coverage history" do

    it "returns the coverage history in the format ACA Entities expects"
  end
end
