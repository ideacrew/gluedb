require "rails_helper"
require File.join(Rails.root,"app","data_migrations","remove_policy_end_date")

describe RemovePolicyEndDate, dbclean: :after_each do
  let(:given_task_name) { "remove_policy_end_date" }
  let(:policy) { FactoryGirl.create(:terminated_policy) }
  let (:enrollees) { policy.enrollees }
  subject { RemovePolicyEndDate.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  before(:each) do
    allow(ENV).to receive(:[]).with("eg_ids").and_return(policy.eg_id)
    allow(ENV).to receive(:[]).with("aasm_state").and_return("submitted")
    allow(ENV).to receive(:[]).with("benefit_status").and_return('active')
  end

  context "removing the end dates" do
    it "should not have any end dates" do
      subject.remove_end_dates(policy)
      policy.reload
      expect(policy.enrollees.map(&:coverage_end).uniq[0]).to be_nil
    end
  end

  context "altering the aasm state" do
    it "should alter the aasm state" do
      aasm_state = policy.aasm_state
      expect(policy.aasm_state).to eq aasm_state
      subject.remove_end_dates(policy)
      subject.change_aasm_state(policy)
      expect(policy.aasm_state).to eq ENV['aasm_state']
      expect(policy.term_for_np).to eq false
    end
  end
end
