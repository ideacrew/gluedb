require 'rails_helper'

describe PdfTemplates::IrsGroup do

  subject { PdfTemplates::IrsGroup.new }

  let(:households) { [ household ] }

  let(:household) { double(has_aptc: true, tax_households: tax_households, coverage_households: [])}
  let(:tax_households) { [ tax_household1, tax_household2 ] }
  let(:tax_household1) { double(policy_ids: [21]) }
  let(:tax_household2) { double(policy_ids: [22]) }

  let(:policies) { [policy1, policy2] }
  let(:policy1) { double(id: 21, subscriber: subscriber1, policy_start: Date.new(2014, 1, 1), policy_end: Date.new(2014, 12, 31)) }
  let(:policy2) { double(id: 22, subscriber: subscriber2, policy_start: Date.new(2014, 6, 1), policy_end: Date.new(2014, 12, 31)) }
  let(:subscriber1) { double(person: person, relationship_status_code: 'Self', coverage_start: Date.new(2014, 1, 1), coverage_end: nil) }
  let(:subscriber2) { double(person: person, relationship_status_code: 'Self', coverage_start: Date.new(2014, 6, 1), coverage_end: nil) }
  let(:person) { double(full_name: 'Ann B Mcc', name_first: 'Ann', name_middle: 'B', name_last: 'Mcc') }
  
  let(:mock_disposition1) { double(start_date: Date.new(2014, 1, 1), end_date: Date.new(2014, 12, 31) ) }
  let(:mock_disposition2) { double(start_date: Date.new(2014, 6, 1), end_date: Date.new(2014, 12, 31) ) }

  let(:month) { 5 }
  let(:year) { 2014 }

  before(:each) do 
    allow(subject).to receive(:households).and_return(households)
    allow(subject).to receive(:policies).and_return(policies)
    allow(subject).to receive(:calendar_year).and_return(year)
    allow(household).to receive(:irs_households).and_return(tax_households)
    allow(PolicyDisposition).to receive(:new).with(policy1).and_return(mock_disposition1)
    allow(PolicyDisposition).to receive(:new).with(policy2).and_return(mock_disposition2)
  end

  it 'should return policy ids from all tax/coverage households' do
    expect(subject.coverage_ids).to eq([21, 22])
  end

  it 'should return households for month' do 
    expect(subject.household_for_month(month)).to eq(household)
  end

  it 'should return active policies for the month' do
    expect(subject.policies_for_month(4)).to eq([policy1])
    expect(subject.policies_for_month(6)).to eq(policies)
  end

  it 'should return tax households with the policies for a particular month' do
    expect(subject.irs_tax_households(4)).to eq([tax_household1])
    expect(subject.irs_tax_households(6)).to eq(tax_households)
  end
end
