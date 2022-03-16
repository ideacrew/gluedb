require "rails_helper"

describe Parsers::Edi::ImportCache do
  before :each do
    allow(Plan).to receive(:all).and_return([])
    allow(Carrier).to receive(:all).and_return([])
  end

  subject { described_class.new }

  it "does not crash when given a year the exchange didn't exist" do
    expect(subject.lookup_plan("BOGUS_HIOS", -3)).to eq nil
  end
end