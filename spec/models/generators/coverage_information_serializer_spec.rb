require 'rails_helper'

describe Generators::CoverageInformationSerializer, :dbclean => :after_each do

  let(:plan)           { FactoryGirl.create(:plan) }
  let(:calender_year)  { Date.today.year }
  let(:coverage_start) { Date.new(calender_year, 1, 1) }
  let(:coverage_end)   { Date.new(calender_year, 12, 31) }

  let(:primary) {
    person = FactoryGirl.create :person, dob: Date.new(1970, 5, 1), name_first: "John", name_last: "Roberts"
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }

  let!(:spouse) {
    person = FactoryGirl.create :person, dob: Date.new(1971, 5, 1), name_first: "Julia", name_last: "Roberts"
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }

  let!(:child)   {
    person = FactoryGirl.create :person, dob: Date.new(1998, 9, 6), name_first: "Adam", name_last: "Roberts"
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }

  let!(:policy) {
    policy = FactoryGirl.create :policy, plan_id: plan.id, coverage_start: coverage_start, coverage_end: coverage_end
    policy.enrollees[0].m_id = primary.authority_member.hbx_member_id
    policy.enrollees[0].coverage_end = nil
    policy.enrollees[1].m_id = child.authority_member.hbx_member_id
    policy.enrollees[1].rel_code ='child'
    policy.enrollees[1].coverage_start = Date.new(calender_year, 6, 1)
    policy.enrollees[1].coverage_end = nil;
    policy.save
    policy
  }

  subject { Generators::CoverageInformationSerializer.new(primary) }

  it 'should build coverage information hash' do
    result = subject.process

    expect(result[0][:coverage_start]).to eq coverage_start.strftime('%Y-%m-%d')
    expect(result[0][:coverage_end]).to eq coverage_end.strftime('%Y-%m-%d')
    expect(result[0][:coverage_kind]).to eq 'individual'
    expect(result[0][:last_maintenance_time]).to eq policy.updated_at.strftime("%H%M%S%L")
    expect(result[0][:enrollees].count).to eq 2
    expect(result[0][:enrollees][0][:segments].count).to eq 2
    expect(result[0][:enrollees][1][:segments].count).to eq 1
    expect(result[0][:enrollees][0][:addresses]).to be_present
  end
end
