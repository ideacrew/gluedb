require 'rails_helper'

module Generators::Reports
  describe IrsHousehold do

    subject { IrsHousehold.new(household) }

    let(:household) { double(tax_households: tax_households) }
    let(:tax_households) { [tax_household1] }
    let(:tax_household1) { double(tax_household_members: tax_household_members_1) }
    let(:tax_household_members_1) { [member1, member2] }
    let(:member1) { double(family_member_id: 1, tax_filing_status: 'tax_filer') }
    let(:member2) { double(family_member_id: 2, tax_filing_status: 'dependent') }
    let(:member3) { double(family_member_id: 3, tax_filing_status: 'tax_filer') }
    let(:enrollments) { [] }

    before(:each) do
      subject.calendar_year = '2014'
      allow(household).to receive(:enrollments_for_year).and_return(enrollments)
    end

    context 'when single tax household present' do 
      it 'should return tax household' do
        allow(subject).to receive(:build_irs_tax_households)
        subject.process
        expect(subject.tax_households).to eq(tax_households)
      end
    end

    context 'when duplicate tax households present ' do
      let(:tax_household2) { double(tax_household_members: tax_household_members_2) }
      let(:tax_household_members_2) { [member1, member2] }
      let(:tax_households) { [tax_household1, tax_household2]}

      it 'should return later tax household' do
        allow(subject).to receive(:build_irs_tax_households)
        subject.process
        expect(subject.tax_households).to eq([tax_household2])      
      end
    end

    context 'when multiple tax households present with both valid and duplicates' do
      let(:tax_household2) { double(tax_household_members: tax_household_members_2) }
      let(:tax_household_members_2) { [member1, member2] }
      let(:tax_household3) { double(tax_household_members: tax_household_members_3) }
      let(:tax_household_members_3) { [member3] } 
      let(:tax_households) { [tax_household1, tax_household2, tax_household3]}

      it 'should return non-duplicate unique tax households' do
        allow(subject).to receive(:build_irs_tax_households)
        subject.process
        expect(subject.tax_households).to eq([tax_household2, tax_household3])      
      end 
    end
  end
end