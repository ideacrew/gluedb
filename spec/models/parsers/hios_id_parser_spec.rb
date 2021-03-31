require "rails_helper"

describe Parsers::HiosIdParser, "given a normal hios id, containing a hypenated csr variant" do
  let(:hios_id) { "78079DC0210001-01" }

  let(:parse_result) { Parsers::HiosIdParser.parse(hios_id) }

  it "is unchanged" do
    expect(parse_result).to eq hios_id
  end
end

describe Parsers::HiosIdParser, "given a hios id containing a non-hypenated csr variant" do
  let(:hios_id) { "78079DC021000101" }
  let(:expected_hios_id) { "78079DC0210001-01" }

  let(:parse_result) { Parsers::HiosIdParser.parse(hios_id) }

  it "adds the hypen" do
    expect(parse_result).to eq expected_hios_id
  end
end

describe Parsers::HiosIdParser, "given a hios id containing no variant" do
  let(:hios_id) { "48396ME0860004" }

  let(:parse_result) { Parsers::HiosIdParser.parse(hios_id) }

  it "is unchanged" do
    expect(parse_result).to eq hios_id
  end
end