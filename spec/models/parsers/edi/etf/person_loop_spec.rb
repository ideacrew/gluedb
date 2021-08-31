require 'rails_helper'

describe Parsers::Edi::Etf::PersonLoop do
  subject(:person_loop) { Parsers::Edi::Etf::PersonLoop.new(raw_loop) }

  let(:ssn_qual) { "34" }

  let(:raw_loop) do
    {
      'L2100A' => {
        "N3" => ['', street1, street2, ''],
        'N4' => ['', city, state, zip],
        'NM1' => ['', '', '', name_last, name_first, name_middle, name_prefix, name_suffix, ssn_qual, ssn],
        'DMG' => ['', '', dob, gender],
      },
      'REFs' => [['', '17', member_id ]],
      'INS' => ['', '', '', change_type]
    }
  end

  let(:street1) { 'something' }
  let(:street2) { 'something' }
  let(:city) { 'Atlanta' }
  let(:state) { 'GA' }
  let(:zip) { '20002' }
  let(:member_id) { '666'}
  let(:name_prefix) { 'Mrs' }
  let(:name_first) { 'Jane' }
  let(:name_middle) { 'X' }
  let(:name_last) { 'Doe' }
  let(:name_suffix) { 'Jr' }
  let(:ssn) { '111111111'}
  let(:gender) { 'M' }
  let(:dob) { '1970-01-01'}
  let(:change_type) { '001' }

  describe 'policy_loops' do
    let(:raw_policy_loop) { Hash.new }
    let(:raw_loop) { { "L2300s" => [raw_policy_loop, raw_policy_loop, raw_policy_loop] } }
    let(:person_loop) { Parsers::Edi::Etf::PersonLoop.new(raw_loop)}
    it 'returns a collection of policy loop instances' do
      expect(person_loop.policy_loops.count).to eq(raw_loop['L2300s'].count)
    end
  end

  it 'exposes first street line' do
    expect(person_loop.street1).to eq street1
  end

  describe 'street line 2' do

    it 'exposes second street line' do
      expect(person_loop.street2).to eq street2
    end

    context 'when blank' do
      let(:street2) { ' ' }
      it 'returns nil' do 
        expect(person_loop.street2).to be_nil
      end
    end
  end

  it 'exposes city' do
    expect(person_loop.city).to eq city
  end

  it 'exposes state' do
    expect(person_loop.state).to eq state
  end

  it 'exposes zip code' do
    expect(person_loop.zip).to eq zip
  end

  it 'exposes member id' do
    expect(person_loop.member_id).to eq member_id
  end

  describe 'middle name' do

    it 'exposes name prefix' do
      expect(person_loop.name_prefix).to eq name_prefix
    end
    context 'when blank' do
      let(:name_prefix) { ' ' }
      it 'returns nil' do
        expect(person_loop.name_prefix).to be_nil
      end
    end
  end
  it 'exposes first name' do
    expect(person_loop.name_first).to eq name_first
  end

  describe 'middle name' do
    it 'exposes middle name' do
      expect(person_loop.name_middle).to eq name_middle
    end

    context 'when blank' do
      let(:name_middle) { ' ' }
      it 'returns nil' do
        expect(person_loop.name_middle).to be_nil
      end
    end
  end

  it 'exposes last name' do
    expect(person_loop.name_last).to eq name_last
  end

  describe 'name suffix' do
    it 'exposes name suffix' do
      expect(person_loop.name_suffix).to eq name_suffix
    end

    context 'when blank' do
      let(:name_suffix) { ' ' }
      it 'returns nil' do
        expect(person_loop.name_suffix).to be_nil
      end
    end
  end

  describe '#cancellation_or_termination?' do
    context 'given no member level detail(INS)' do
      let(:raw_loop) { { "INS" => [] } }
      it 'returns false' do
        expect(person_loop.cancellation_or_termination?).to eq false
      end
    end

    context 'given member level detail stating cancellation or termination' do
      let(:raw_loop) { { "INS" => ['', '', '', '024'] } }
      it 'returns true' do
        expect(person_loop.cancellation_or_termination?).to eq true
      end
    end

    context 'given some other maintainance type code' do
      let(:raw_loop) { { "INS" => ['', '', '', '666'] } }
      it 'returns false' do
        expect(person_loop.cancellation_or_termination?).to eq false
      end
    end
  end

  describe 'ssn' do
    it 'exposes ssn' do
      expect(person_loop.ssn).to eq ssn
    end

    context "when qualifier is empty" do
      let(:ssn_qual) { nil }
      it 'returns nil' do 
        expect(person_loop.ssn).to be_nil
      end
    end

    context "when qualifier is not 34" do
      let(:ssn_qual) { "NOT 34" }

      context "when ssn is equal to member_id" do
        let(:ssn) { member_id }
        it 'returns nil' do 
          expect(person_loop.ssn).to be_nil
        end
      end

      context "when ssn is NOT equal to member_id" do
        context "when 9 numbers" do
          let(:ssn) { "9" * 9 }

          it 'returns ssn' do 
            expect(person_loop.ssn).to eq ssn
          end
        end

        context 'when blank' do
          let(:ssn) { ' '}
          it 'returns nil' do 
            expect(person_loop.ssn).to be_nil
          end
        end
      end
    end

    context "when qualifier is 34" do
      let(:ssn_qual) { "34" }

      context 'when blank' do
        let(:ssn) { ' '}
        it 'returns nil' do 
          expect(person_loop.ssn).to be_nil
        end
      end

      context 'when too short' do
        let(:ssn) { '1'}
        it 'returns nil' do
          expect(person_loop.ssn).to be_nil
        end
      end

      context 'when too long' do
        let(:ssn) { '1' * 10 }
        it 'returns nil' do
          expect(person_loop.ssn).to be_nil
        end
      end
    end
  end

  it 'exposes gender' do
    expect(person_loop.gender).to eq gender
  end

  describe 'date of birth' do
    it 'exposes date of birth' do
      expect(person_loop.date_of_birth).to eq dob
    end
    context 'when blank' do
      let(:dob) { ' ' }
      it 'returns nil' do
        expect(person_loop.date_of_birth).to be_nil
      end
    end
  end

  describe 'change type' do

    context 'when change' do
      let(:change_type) { '001' }
      it 'returns change' do
        expect(person_loop.change_type).to eq :change
      end
    end

    context 'when stop' do
      let(:change_type) { '024' }
      it 'returns stop' do
        expect(person_loop.change_type).to eq :stop
      end
    end

    context 'when anything else' do
      let(:change_type) { ' ' }
      it 'returns add' do
        expect(person_loop.change_type).to eq :add
      end
    end
  end

  it "is not a reinstate" do
    expect(person_loop.reinstate?).to be_falsey
  end
end

describe Parsers::Edi::Etf::PersonLoop, "representing a reinstate" do
  subject(:person_loop) { Parsers::Edi::Etf::PersonLoop.new(raw_loop) }

  let(:ssn_qual) { "34" }

  let(:raw_loop) do
    {
      'L2100A' => {
        "N3" => ['', street1, street2, ''],
        'N4' => ['', city, state, zip],
        'NM1' => ['', '', '', name_last, name_first, name_middle, name_prefix, name_suffix, ssn_qual, ssn],
        'DMG' => ['', '', dob, gender],
      },
      'REFs' => [['', '17', member_id ]],
      'INS' => ['', '', '', change_type]
    }
  end

  let(:street1) { 'something' }
  let(:street2) { 'something' }
  let(:city) { 'Atlanta' }
  let(:state) { 'GA' }
  let(:zip) { '20002' }
  let(:member_id) { '666'}
  let(:name_prefix) { 'Mrs' }
  let(:name_first) { 'Jane' }
  let(:name_middle) { 'X' }
  let(:name_last) { 'Doe' }
  let(:name_suffix) { 'Jr' }
  let(:ssn) { '111111111'}
  let(:gender) { 'M' }
  let(:dob) { '1970-01-01'}
  let(:change_type) { '025' }

  it "is a reinstate" do
    expect(person_loop.reinstate?).to be_truthy
  end
end