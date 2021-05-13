require 'spec_helper' #needed for '.blank?'
#'./app/models/parsers/edi/etf/person_parser'

describe Parsers::Edi::Etf::PersonParser do
  subject(:parser) { Parsers::Edi::Etf::PersonParser.new(l2000) }

  let(:l2000) do
    {
      'L2100A' => {
        "N3" => ['', street1, street2, ''],
        'N4' => ['', city, state, zip, '', 'CY', county_code]
      },
      'REFs' => [['', '17', member_id ]]
    }
  end
  let(:street2) { 'something' }
  let(:street1) { 'something' }
  let(:city) { 'Atlanta' }
  let(:state) { 'GA' }
  let(:zip) { '20002' }
  let(:county_code) { '10010' }
  let(:member_id) { '666' }

end
