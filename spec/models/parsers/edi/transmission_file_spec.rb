require 'spec_helper'
require 'rails_helper'

describe Parsers::Edi::TransmissionFile, :dbclean => :after_each do
  let(:pb) { double(:refresh => nil) }
  let(:transmission_file) { Parsers::Edi::TransmissionFile.new(' ', ' ', ' ', nil, pb) }
  describe '#persist_broker_get_id' do
    context 'transmission has no broker loop' do
      let(:etf_loop) { {"L1000C" => Hash.new } }
      it 'returns nil' do
        expect(transmission_file.persist_broker_get_id(etf_loop)).to eq nil
      end
    end

    context 'transmission has broker loop' do
      let(:name) { 'SuperBroker' }
      let(:npn) { 'npn' }
      let(:etf_loop) { { 'L1000C' => { 'N1' => ['','', name, '', npn] } } }
      context 'npn absent' do
        let(:npn) { ' ' }
        it 'returns nil' do
          expect(transmission_file.persist_broker_get_id(etf_loop)).to eq nil
        end
      end

      context 'npn present' do
        it 'returns a broker id' do
          expect(transmission_file.persist_broker_get_id(etf_loop)).not_to eq nil
        end
      end
    end
  end

  describe '#transaction_set_kind' do
    context 'transmission is not an effectuation' do
      it 'returns the kind unchanged' do
        kind = 'something'
        etf = Parsers::Edi::Etf::EtfLoop.new({'L2000s' => [ { "INS" => ['', '', '', ''] } ]})
        transmission_file.transmission_kind = kind
        expect(transmission_file.transaction_set_kind(etf)).to eq kind
      end
    end

    context 'transmission_kind is an effectuation' do
      let(:kind) { 'effectuation' }
      before { transmission_file.transmission_kind = kind }
      context 'cancellation or term' do
        it 'returns maintenance' do
          etf = Parsers::Edi::Etf::EtfLoop.new({'L2000s' => [ { "INS" => ['', '', '', '024'] } ]})
          expect(transmission_file.transaction_set_kind(etf)).to eq 'maintenance'
        end
      end

      context 'not a cancellation or term' do
        it 'returns the kind unchanged' do
          etf = Parsers::Edi::Etf::EtfLoop.new({'L2000s' => [ { "INS" => ['', '', '', 'xxx'] } ]})
          expect(transmission_file.transaction_set_kind(etf)).to eq kind
        end
      end
    end
  end

  describe '#responsible_party_loop' do
    let(:data) { 'the_data'}

    context 'when data is in Custodial Parent (2100f)' do
      let(:person_loops) { [ { 'L2100F' => data } ]  }
      it 'returns the loop data' do
        expect(transmission_file.responsible_party_loop(person_loops)).to eq data
      end
    end

    context 'when data is in Responsible Person(2100g)' do
      let(:person_loops) { [ { 'L2100G' => data } ] }
      it 'returns the loop data' do
        expect(transmission_file.responsible_party_loop(person_loops)).to eq data
      end
    end
  end

  describe '#persist_responsible_party_get_id' do
    let(:id) { 1 }
    let(:person) { Person.new(name_first: 'Joe', name_last: 'Dirt') }
    let(:responsible_party) { ResponsibleParty.new(_id: id, entity_identifier: "parent") }
    let(:eg_id) { "100" }
    let(:existing_policy) {  FactoryGirl.create(:policy, enrollment_group_id: eg_id)}

    before do
      person.responsible_parties << responsible_party
      person.save!
      existing_policy.responsible_party_id = responsible_party._id
      existing_policy.save
      existing_policy.reload
    end

    context 'when L2100F has no responsible party ' do
      let(:person_loops) { { 'L2000s' => [] }   }

      it 'returns existing policy responsible_party id' do
        expect(transmission_file.persist_responsible_party_get_id(person_loops, eg_id)).to eq existing_policy.responsible_party_id
      end
    end
  end
end
