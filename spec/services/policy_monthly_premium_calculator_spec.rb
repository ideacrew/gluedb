require "rails_helper"

describe Services::PolicyMonthlyPremiumCalculator do
  let!(:child)   {
    person = FactoryGirl.create :person, dob: Date.new(1998, 9, 6)
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }
  let!(:plan) { FactoryGirl.create(:plan) }
  let!(:primary) {
    person = FactoryGirl.create :person, dob: Date.new(1970, 5, 1)
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }
  let(:coverage_start) {Date.new(2019, 1, 1)}
  let(:coverage_end) {coverage_start.end_of_year}
  let(:policy) {
    policy = FactoryGirl.create :policy, plan_id: plan.id, coverage_start: coverage_start, coverage_end: coverage_end, kind: 'individual'
    policy.enrollees[0].m_id = primary.authority_member.hbx_member_id
    policy.enrollees[1].m_id = child.authority_member.hbx_member_id
    policy.enrollees[1].rel_code ='child'; policy.save
    policy
  }
  let(:policy_disposition) {PolicyDisposition.new(policy)}
  let(:calender_year) {2019}

  subject(:prem_amount) { Services::PolicyMonthlyPremiumCalculator.new(policy_disposition: policy_disposition, calender_year: calender_year)}

  it 'returns the policy premium amount' do
    expect(prem_amount.ehb_premium_for(1).round(2)).to eq policy.pre_amt_tot
  end
end
