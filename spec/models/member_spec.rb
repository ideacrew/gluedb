require 'rails_helper'

describe Member, :dbclean => :after_each do
  before(:each) do
    @p1 = Person.create!(
          name_pfx: "Mrs",
          name_first: "Jane",
          name_middle: "Jacob",
          name_last: "Jingle-Himer"
          )

    @p2 = Person.create!(
          name_first: "Sam",
          name_last: "Spade"
          )
  end

  describe "it should instantiate object" do
    let(:hbx_member_id) { "dc123243" }
    let(:date_1) { Time.new(1980,10,23,0,0,0) }
    let(:good_ssn) { "789999999" }
    let(:gender) { "female" }
    let(:tobacco) {"unknown"}
    let(:language) { "en"}
    let(:leading_zero_ssn) { "002450900" }

    it "sets and gets all basic model fields" do
      mbr = Member.new(
        hbx_member_id: hbx_member_id,
        dob: date_1,
        ssn: good_ssn,
        gender: gender,
        hlh: tobacco,
        lui: language
        )
      p = @p1
      p.members << mbr

      expect(p.members.first.hbx_member_id).not_to eq(nil)
      expect(p.members.first.hbx_member_id).to eq(hbx_member_id)
    end

    it "automatically assigns hbx_member_id if value isn't provided" do
      p = Person.find(@p2.id)
      p.members.build(
        dob: date_1,
        ssn: leading_zero_ssn,
        gender: gender,
        hlh: tobacco,
        lui: language
        )
      p.save!

      expect(p.members.first.hbx_member_id).not_to eq(nil)
      expect(p.members.first.hbx_member_id).to eq(p.members.first.id.to_s)
      expect(p.members.first.ssn).to eq(leading_zero_ssn)
    end
  end

end

describe Member, :dbclean => :after_each do
  let(:dob) { "19640229" }
  let(:name_last) { "LaName" }
  let(:name_first) { "Exampile" }
  let(:gender) { "male" }

  subject {
    Member.new(
      name_first: name_first,
      name_last: name_last,
      dob: dob,
      gender: gender
    )
  }

  it { should be_valid }

  it "should be valid with a blank ssn" do
    subject.ssn = ""
    expect(subject).to be_valid
  end

  it "should be valid with a nil ssn" do
    subject.ssn = nil
    expect(subject).to be_valid
  end

  it "should be valid with a nil hbx_member_id" do
    subject.hbx_member_id = nil
    expect(subject).to be_valid
  end

  describe 'setters' do
    let(:member) { Member.new }
    describe 'ssn' do
      it 'removes all non-numerals' do
        member.ssn = 'a2a2b2ccc2d2ee2f2gg2h2'
        expect(member.ssn).to eq '222222222'
      end
    end

    describe 'gender' do
      it 'forces to lowercase' do
        member.gender = 'fEMaLE'
        expect(member.gender).to eq 'female'
      end
    end
  end

  describe 'associated lookup by hbx_member_id' do
    let(:member) { Member.new(gender: 'male') }
    let(:id_to_lookup) { '666' }
    let(:different_id) { '777' }
    let(:enrollee) { Enrollee.new(relationship_status_code: 'self', employment_status_code: 'active', benefit_status_code: 'active') }
    let(:policy) { Policy.new(eg_id: '1', plan_id: '1') }

    describe '#policies' do
      it 'finds policies who has an enrollee with a matching hbx_member_id' do
        member.hbx_member_id = id_to_lookup
        enrollee.m_id = id_to_lookup

        policy.enrollees << enrollee
        policy.save!

        unrelated_enrollee = Enrollee.new(m_id: different_id, relationship_status_code: 'spouse', employment_status_code: 'active', benefit_status_code: 'active')
        other_policy = Policy.new(eg_id: '1111', plan_id: '1')
        other_policy.enrollees << unrelated_enrollee
        other_policy.save!

        expect(member.policies.to_a).to eq [policy]
      end
    end

    describe '#enrollees' do
      it 'finds enrollees with matching hbx_member_ids' do
        member.hbx_member_id = id_to_lookup
        enrollee.m_id = id_to_lookup

        policy.enrollees << enrollee
        policy.save!

        unrelated_enrollee = Enrollee.new(m_id: different_id, relationship_status_code: 'spouse', employment_status_code: 'active', benefit_status_code: 'active')
        other_policy = Policy.new(eg_id: '111111', plan_id: '1')
        other_policy.enrollees << unrelated_enrollee
        other_policy.save!

        expect(member.enrollees).to eq [enrollee]
      end
    end
  end

  describe '#authority?' do
    let(:member) { Member.new(gender: 'male') }
    let(:person) { Person.new(name_first: 'Joe', name_last: 'Dirt') }
    before { person.members << member }

    context 'members hbx id equals the person authority member id' do
      before do
        person.authority_member_id = '666'
        member.hbx_member_id = '666'
      end
      it 'returns true' do
        expect(member.authority?).to eq true
      end
    end

    context 'members hbx id NOT equal to the person authority member id' do
      before do
        person.authority_member_id = '666'
        member.hbx_member_id = '7'
      end
      it 'returns true' do
        expect(member.authority?).to eq false
      end
    end
  end

  describe '.find_for_member_id' do
    let(:id_to_lookup) { '666' }
    let(:person) { Person.new(name_first: 'Joe', name_last: 'Dirt') }
    let(:member) { Member.new(gender: 'male') }

    context 'a person has a member with matching hbx_member_id' do
      before do
        member.hbx_member_id = id_to_lookup
        person.members << member
        person.save!
      end
      it 'returns member' do
        expect(Member.find_for_member_id(id_to_lookup)).to eq member
      end
    end

    context 'no person has a member with matching hbx_member_id' do
      before do
        member.hbx_member_id = id_to_lookup.next
        person.members << member
        person.save!
      end
      it 'returns nil' do
        expect(Member.find_for_member_id(id_to_lookup)).to eq nil
      end
    end
  end
end
