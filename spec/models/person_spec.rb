require 'rails_helper'

describe Person, :dbclean => :after_each do
  describe "instantiates object." do
		it "sets and gets all basic model fields" do
      psn = Person.new(
        name_pfx: "Mr",
        name_first: "John",
        name_middle: "Jacob",
        name_last: "Jingle-Himer",
        name_sfx: "Sr"
      )
      expect(psn.name_pfx).to eql("Mr")
      expect(psn.name_first).to eql("John")
      expect(psn.name_middle).to eql("Jacob")
      expect(psn.name_last).to eql("Jingle-Himer")
      expect(psn.name_sfx).to eql("Sr")
    end
  end

  describe "manages embedded contact attributes" do
    it "sets and gets address attributes" do
      psn = Person.new
      psn.addresses << Address.new(
        address_type: "work",
        address_1: "101 Main St",
        address_2: "Apt 777",
        city: "Washington",
        state: "DC",
        zip: "20001"
      )
    end

    it "sets and gets email attributes" do
      psn = Person.new
      psn.emails << Email.new(
        email_type: "work",
        email_address: "john.Jingle-Himer@example.com"
      )
    end

    it "sets and gets phone attributes" do
      psn = Person.new
      psn.phones << Phone.new(
        phone_type: "mobile",
        phone_number: "+1-202-555-1212"
      )
    end
  end

  describe "manages member roles" do

    # This is mainly because I hate instance variables.
    let(:mbr_id) { "1234"}

    before :each do
      @date1 = Time.new(1980,10,23,0,0,0)
      @mbr_ssn = 789999999
      @mbr_sex = "female"
      @mbr_tobacco = "unknown"
      @mbr_language = "en"
    end
    it "appends multiple members" do
      psn = Person.new
      psn.members << Member.new(
        hbx_member_id: mbr_id,
        dob: @date1,
        ssn: @mbr_ssn,
        gender: @mbr_sex,
        tobacco_use_code: @mbr_tobacco,
        lui: @mbr_language
      )
      psn.members << Member.new(
        hbx_member_id: (mbr_id.to_i + 100).to_s,
        dob: @date1,
        ssn: @mbr_ssn,
        gender: @mbr_sex,
        tobacco_use_code: @mbr_tobacco,
        lui: @mbr_language
      )
      m = psn.members.first
      expect(m.hbx_member_id).to eql(mbr_id)
      expect(m.dob.strftime("%m/%d/%Y")).to eql(@date1.strftime("%m/%d/%Y"))
      expect(m.gender).to eql(@mbr_sex)
      expect(m.tobacco_use_code).to eql(@mbr_tobacco)
      expect(m.lui).to eql(@mbr_language)

    end
  end

  describe "set auhority member" do
    let(:mbr_id) { "1234"}

    before :each do
      @date1 = Time.new(1980,10,23,0,0,0)
      @mbr_ssn = 789999999
      @mbr_sex = "female"
      @mbr_tobacco = "unknown"
      @mbr_language = "en"
    end

    it "sets authority member id on person" do
      psn = Person.new(
        name_pfx: "Mr",
        name_first: "John",
        name_middle: "Jacob",
        name_last: "Jingle-Himer",
        name_sfx: "Sr"
      )

      psn.members << Member.new(
        hbx_member_id: mbr_id,
        dob: @date1,
        ssn: @mbr_ssn,
        gender: @mbr_sex,
        tobacco_use_code: @mbr_tobacco,
        lui: @mbr_language
      )
      psn.save
      expect(psn.authority_member.hbx_member_id).to eq mbr_id
    end
  end

  describe "manages enrollment roles" do
    # it "Sets MemberEnrollment attributes" do
    # 	psn = Person.first
    # 	psn.member_enrollments << MemberEnrollment.new(
    # 			enrollment_id: 343434,
    # 			subscriber_id: 4545,
    # 			disability_status: false,
    # 			carrier_id: 5656,
    # 			benefit_status_code: "active",
    # 			relationship_status_code: "self")
    # 	psn.save!
    # end
  end


  describe "manages responsible party roles" do
  end


  describe "tracks changes" do
    it "in embedded models" do

      p =	Person.create!({
        name_pfx: "Dr",
        name_first: "Leonard",
        name_middle: "H",
        name_last: "McCoy",
        members: [
          Member.new({gender: "female", ssn: "564781254", dob: "19890312"})
        ],
        addresses: [
          Address.new({address_type: "home", address_1: "110 Main St", city: "Washington", state: "DC", zip: "20001"}),
          Address.new({address_type: "work", address_1: "222 Park Ave", city: "Washington", state: "DC", zip: "20002"})
        ]
      })

      q = Person.find p
      q.name_first = "Bones"
      q.members.first.gender = "male"
      q.addresses.first.address_type = "billing"
      q.addresses.last.state = "CA"

      delta = q.changes_with_embedded
      expect(delta[:person].first[:name_first][:from]).to eq("Leonard")
      expect(delta[:person].first[:name_first][:to]).to eq("Bones")

      expect(delta[:addresses].first[:address_type][:to]).to eq("billing")
      expect(delta[:addresses].last[:state][:to]).to eq("CA")

      expect(delta[:members].first[:gender][:to]).to eq("male")
    end
  end

  describe 'authority member id assignment' do
    let(:person) { Person.new }
    context 'one member' do
      let(:member) { Member.new(hbx_member_id: 1) }
      it 'authority member id is the member hbx id' do
        person.members << member
        person.assign_authority_member_id
        expect(person.authority_member_id).to eq member.hbx_member_id
      end
    end
    context 'more than one member' do
      it 'authority member id is nil' do
        2.times { |i| person.members << Member.new(hbx_member_id: i) }
        person.assign_authority_member_id
        expect(person.authority_member_id).to be_nil
      end
    end
  end

  describe 'being searched for members' do
    let(:member_ids) { ["a", "b" "c" ] }

    let(:query) { Queries::PersonMemberQuery.new(member_ids) }

    it "should search for the specified members" do
      expect(Person).to receive(:where).with(query.query)
      Person.find_for_members(member_ids)
    end
  end

  describe '#full_name' do
    let(:person) { Person.new(name_pfx: 'Mr', name_first: 'Joe', name_middle: 'X', name_last: 'Dirt', name_sfx: 'Jr') }
    it 'returns persons full name as string' do
      expect(person.full_name).to eq 'Mr Joe X Dirt Jr'
    end
  end

  describe '#addresses_match?' do
    context 'unequal count of home addresses' do
      it 'returns false' do
        person = Person.new
        person.addresses << Address.new(address_type: 'home')
        person.addresses << Address.new(address_type: 'home')

        other_person = Person.new
        other_person.addresses << Address.new(address_type: 'home')

        expect(person.addresses_match?(other_person)).to be_false
      end
    end

    context 'no home addresses match' do
      it 'returns false' do
        person = Person.new
        person.addresses << Address.new(address_type: 'home', city: 'Boston')

        other_person = Person.new
        other_person.addresses << Address.new(address_type: 'home', city: 'New York')

        expect(person.addresses_match?(other_person)).to be_false
      end
    end

    context 'home address count and values match' do
      it 'returns true' do
        person = Person.new
        person.addresses << Address.new(address_type: 'home', city: 'Boston')

        other_person = Person.new
        other_person.addresses << Address.new(address_type: 'home', city: 'Boston')

        expect(person.addresses_match?(other_person)).to be_true
      end
    end
  end


  describe '#home_address' do
    context 'home address exists' do
      it 'returns the first home address' do
        person = Person.new
        address = Address.new(address_type: 'home')
        another_address = Address.new(address_type: 'home')

        person.addresses << address
        person.addresses << another_address

        expect(person.home_address).to eq address
      end
    end
    context 'home address doesnt exist' do
      it 'returns nil' do
        person = Person.new
        person.addresses << Address.new(address_type: 'work')
        expect(person.home_address).to be_nil
      end
    end
  end

  describe '#home_phone' do
    context 'home phone exists' do
      it 'returns the first home phone' do
        person = Person.new
        home_phone = Phone.new(phone_type: 'home')
        other_phone = Phone.new(phone_type: 'home')

        person.phones << home_phone
        person.phones << other_phone

        expect(person.home_phone).to eq home_phone
      end
    end
    context 'home phone doesnt exist' do
      it 'returns nil' do
        person = Person.new
        person.phones << Phone.new(phone_type: 'work')
        expect(person.home_phone).to be_nil
      end
    end
  end

  describe '#home_email' do
    context 'home email exists' do
      it 'returns the first home email' do
        person = Person.new
        home_email = Email.new(email_type: 'home')
        other_email = Email.new(email_type: 'home')

        person.emails << home_email
        person.emails << other_email

        expect(person.home_email).to eq home_email
      end
    end
    context 'home email doesnt exist' do
      it 'returns nil' do
        person = Person.new
        person.emails << Email.new(email_type: 'work')
        expect(person.home_email).to be_nil
      end
    end
  end

  describe '.find_for_member_id' do
    let(:person) { Person.new(name_first: 'Joe', name_last: 'Dirt') }
    let(:member) { Member.new(gender: 'male') }
    let(:lookup_id) { '666' }
    let(:different_id) { '777'}
    context 'no person has members with the hbx id' do
      before do
        member.hbx_member_id = different_id
        person.members << member
        person.save!
      end

      it 'returns nil' do
        expect(Person.find_for_member_id(lookup_id)).to eq nil
      end
    end

    context 'person has members with the hbx id' do
      before do
        member.hbx_member_id = lookup_id
        person.members << member
        person.save!
      end
      it 'returns the person' do
        expect(Person.find_for_member_id(lookup_id)).to eq person
      end
    end
  end

  describe '#future_active_policies' do
    let(:person) { Person.new(name_first: 'Joe', name_last: 'Dirt', members: [member]) }
    let(:member) { Member.new(hbx_member_id: '1', gender: 'male', ssn: '11111111111')}
    let(:policy) { Policy.new(eg_id: '1', enrollees: [enrollee], plan: plan ) }
    let(:plan) { build(:plan) }
    let(:enrollee) do
      Enrollee.new(
        m_id: member.hbx_member_id,
        benefit_status_code: 'active',
        employment_status_code: 'active',
        relationship_status_code: 'self',
        coverage_start: future_date)
    end
    let(:future_date) { Date.today.next_month }
    before { policy.save! }

    it 'returns policies that will be active in the future' do
      expect(person.future_active_policies).to eq [policy]
    end
  end

  describe '#billing_address' do
    let(:person) { Person.new(name_first: 'Joe', name_last: 'Dirt') }
    let(:address) {
        Address.new(
        address_type: address_type,
        address_1: "101 Main St",
        address_2: "Apt 777",
        city: "Washington",
        state: "DC",
        zip: "20001"
      ) }

    before { person.addresses << address }

    context 'when there is a billing address' do
      let(:address_type) { 'billing' }

      it 'returns the billing address' do
        expect(person.billing_address).to eq address
      end
    end

    context 'when there is no billing address' do
      context 'but there is a home address' do
        let(:address_type) { 'home' }

        it 'returns the home address' do
          expect(person.billing_address).to eq address
        end
      end
    end
  end
end

describe Person do
  subject { Person.new(addresses: [address]) }
  let(:address) { Address.new(address_type: 'home') }

  it 'has a home address' do
    expect(subject.address_of('home')).to eq address
  end

end
