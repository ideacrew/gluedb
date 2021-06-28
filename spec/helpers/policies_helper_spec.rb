require 'rails_helper'

RSpec.describe PoliciesHelper, :type => :helper do

  describe "is_is_policy_not_eligible_to_notify?" do

    let(:today) { Time.now }
    let(:current_year) { ((today.beginning_of_year)..today.end_of_year) }
    let(:future_year) { ((today.beginning_of_year + 1.year)..(today.end_of_year + 1.year)) }
    let(:coverage_year_first) { (Time.mktime(2018, 1, 1)..Time.mktime(2018, 12, 31) )}
    let(:coverage_year_too_old) { (Time.mktime(2017, 1, 1)..Time.mktime(2017, 12, 31) )}
    let(:plan) { build(:plan, metal_level: "platinum")}

    context "given a shop policy" do
      let(:policy) do
        instance_double(
          Policy,
          is_shop?: true,
          kind: 'employer_sponsored'
        )
      end

      it "returns true" do
        expect(helper.is_policy_not_eligible_to_notify?(policy)).to be_truthy
      end
    end

    context 'given a coverall kind policy' do
      let(:policy) do
        instance_double(
          Policy,
          is_shop?: false,
          kind: 'coverall'
        )
      end

      it "returns true" do
        expect(helper.is_policy_not_eligible_to_notify?(policy)).to be_truthy
      end
    end

    context 'given a health policy with catastrophic plan' do
      let(:policy_id) { "A POLICY ID" }
      let(:eg_id) { "A POLICY ID" }
      let(:policy) do
        instance_double(
          Policy,
          :id => policy_id,
          :eg_id => eg_id,
          is_shop?: false,
          kind: 'individual',
          plan: plan
        )
      end
      let(:plan) { build(:plan, metal_level: "catastrophic")}

      it "returns true" do
        expect(helper.is_policy_not_eligible_to_notify?(policy)).to be_truthy
      end
    end

    context "given a dental policy" do
      let(:policy) do
        instance_double(
          Policy,
          is_shop?: true,
          coverage_type: "dental",
          kind: 'employer_sponsored'
        )
      end

      it "returns true" do
        expect(helper.is_policy_not_eligible_to_notify?(policy)).to be_truthy
      end
    end

    context "given an ivl policy from the current year" do
      let(:policy) do
        instance_double(
          Policy,
          is_shop?: false,
          kind: 'individual',
          coverage_year: current_year,
          coverage_type: "health",
          plan: plan
        )
      end

      it "returns true" do
        expect(helper.is_policy_not_eligible_to_notify?(policy)).to be_truthy
      end
    end

    context "given an ivl policy from the future year" do
      let(:policy) do
        instance_double(
          Policy,
          is_shop?: false,
          kind: 'individual',
          coverage_year: future_year,
          coverage_type: "health",
          plan: plan
        )
      end

      it "returns true" do
        expect(helper.is_policy_not_eligible_to_notify?(policy)).to be_truthy
      end
    end

    context "given an ivl policy from before 2018" do
      let(:policy) do
        instance_double(
          Policy,
          is_shop?: false,
          kind: 'individual',
          coverage_year: coverage_year_too_old,
          coverage_type: "health",
          plan: plan
        )
      end

      it "returns false" do
        expect(helper.is_policy_not_eligible_to_notify?(policy)).to be_falsey
      end
    end

    context "given an ivl policy from a previous policy year, after 1/1/2018" do
      let(:policy_id) { "A POLICY ID" }
      let(:eg_id) { "A POLICY ID" }

      let(:policy) do
        instance_double(
          Policy,
          :id => policy_id,
          :eg_id => eg_id,
          is_shop?: false,
          kind: 'individual',
          coverage_year: coverage_year_first,
          coverage_type: "health",
          plan: plan
        )
      end

      it "return false" do
        expect(helper.is_policy_not_eligible_to_notify?(policy)).to be_falsey
      end
    end
  end

  describe "disable_radio_button?" do

    context "canceled policy" do
      let(:policy) { FactoryGirl.create(:policy, aasm_state: 'canceled') }

      it "should return true" do
        expect(helper.disable_radio_button?(policy)).to be_truthy
      end
    end

    context "canceled policy" do
      let(:policy) { FactoryGirl.create(:policy, aasm_state: 'submitted') }

      it "should return false" do
        expect(helper.disable_radio_button?(policy)).to be_falsey
      end
    end
  end
end
