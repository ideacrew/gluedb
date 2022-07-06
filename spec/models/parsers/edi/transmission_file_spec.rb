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

  describe '#persist and #run_imports' do
    let(:eg_id) { "123" }
    let!(:carrier) {
      carrier = Carrier.create!
      carrier.carrier_profiles << CarrierProfile.new(fein: "12345")
      carrier
    }
    let(:plan) { Plan.create!(:name => "test_plan", :coverage_type => "health", hios_plan_id: "48396ME0710075-01") }
    let!(:existing_policy) do
      pol = FactoryGirl.create(:policy, plan: plan)
      pol.eg_id = eg_id
      pol.hbx_enrollment_ids = [eg_id]
      pol.save
      pol
    end

    context 'when process invalid payload ' do
      let(:incoming_edi) { <<-STRING
        {"GS":[1,"BE","ME0","IND","19990607","1053","6459","X","555555"],"GE":[60,"1","6459"],"L834s":[{"L1000A":{"N1":[7,"P5","ME0","FI","111111111"]},"RAW_CONTENT":"","L2000s":[{"INS":[9,"Y","18","024","07","A","","","TE","","N"],"LS":[23,"2700"],
        "L2700s":[{"LX":[24,"1"],"L2750":{"DTP":[27,"007","D8","20220701"],"N1":[25,"75","APTC AMT"],"REF":[26,"9V","0.00"]}},{"LX":[28,"2"],"L2750":{"N1":[29,"75","CARRIER TO BILL"],"REF":[30,"ZZ","TRUE"]}},{"LX":[31,"3"],"L2750":{"DTP":[34,"007","D8","20220701"],
        "N1":[32,"75","PRE AMT 1"],"REF":[33,"9X","383.14"]}},{"LX":[35,"4"],"L2750":{"DTP":[38,"007","D8","20220701"],"N1":[36,"75","PRE AMT TOT"],"REF":[37,"9X","383.14"]}},{"LX":[39,"5"],"L2750":{"DTP":[42,"007","D8","20220701"],"N1":[40,"75","TOT RES AMT"],
        "REF":[41,"9V","383.14"]}},{"LX":[43,"6"],"L2750":{"N1":[44,"75","RATING AREA"],"REF":[45,"9X","R-ME003"]}},{"LX":[46,"7"],"L2750":{"N1":[47,"75","REQUEST SUBMIT TIMESTAMP"],
        "REF":[48,"17","2022060714411900"]}},{"LX":[49,"8"],"L2750":{"N1":[50,"75","SEP REASON"],"REF":[51,"17","NE"]}},{"LX":[52,"9"],"L2750":{"N1":[53,"75","SOURCE EXCHANGE ID"],"REF":[54,"17","ME0"]}},{"LX":[55,"10"],"L2750":{"N1":[56,"75","ADDL MAINT REASON"],"REF":[57,"17","CANCEL"]}}],
        "REFs":[[10,"0F","1174864"],[11,"17","1174864"]],"DTPs":[[12,"303","D8","20220607"]],"L2100A":{"N4":[16,"test Falls","ME","04252","","CY","23001"],"NM1":[13,"IL","1","Test G","Test K","","","","34","7777777"],
        "ECs":[],"N3":[15,"35 test","Apt B"],"LUIs":[[18,"LE","EN","","5"]],"PER":[14,"IP","","TE","8888888","EM","test@gmail.com"],"DMG":[17,"D8","19920603","M"]},"L2300s":[{"HD":[19,"024","","HLT"],
        "REFs":[[21,"CE","48396ME071007501"],[22,"1L","123"]],"DTPs":[[20,"349","D8","20220701"]]}],"LE":[58,"2700"]}],"DTP":[4,"303","D8","20220607"],"SE":[59,"58","528798174"],
        "L1000C":{"N1":[-1,"","","","77777"]},"QTYs":[[5,"DT","0"],[6,"TO","6"]],"L1000B":{"N1":[8,"IN","ANTHM_IND","FI","12345"]},"ST":[2,"834","528798174","005010X220A1"],"BGN":[3,"00","2022060714411900664785","20220607","144119","UT","","","2"]}],
        "IEA":[61,"1","100005495"],"ISA":[0,"00","          ","00","          ","30","016000001      ","30","12345      ","220607","1053","^","00501","100005495","1","T",":"]}
      STRING
      }

      it 'should set policy id and store errors on TransactionSetEnrollment' do
        expect(Protocols::X12::Transmission.all.count).to eq 0
        expect(Protocols::X12::TransactionSetEnrollment.all.count).to eq 0

        Parsers::Edi::TransmissionFile.init_imports
        cache = Parsers::Edi::ImportCache.new
        Parsers::Edi::TransmissionFile.new(' ', 'maintenance', incoming_edi, cache, pb).persist!
        Parsers::Edi::TransmissionFile.run_imports

        expect(Protocols::X12::Transmission.all.count).to eq 1
        expect(Protocols::X12::TransactionSetEnrollment.all.count).to eq 1
        expect(Protocols::X12::TransactionSetEnrollment.all.last.policy).to eq existing_policy
        expect(Protocols::X12::TransactionSetEnrollment.all.last.carrier).to eq carrier
        expect(Protocols::X12::TransactionSetEnrollment.all.last.error_list).to eq ["Broker Information is invalid"]
      end
    end
  end
end
