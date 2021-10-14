require 'rails_helper'

describe Parsers::Edi::PersonLoopValidator do
  let(:person_loop) do
    double(
      carrier_member_id: carrier_member_id,
      policy_loops: policy_loops,
      reinstate?: false
    )
  end
  let(:listener) { double }
  let(:policy_loops) { [policy_loop] }
  let(:policy_loop) { double(action: :change) }
  let(:policy) { nil }
  let(:validator) { Parsers::Edi::PersonLoopValidator.new }

  context ' carrier member id is missing' do
    let(:carrier_member_id) { ' ' }
    it 'notifies listener of missing carrier member id' do
      expect(listener).to receive(:missing_carrier_member_id).with(person_loop)
      expect(validator.validate(person_loop, listener, policy)).to eq false
    end
  end

  context 'carrier member id is present' do
    let(:carrier_member_id) { '1234' }

    it 'notifies listener of found carrier member id' do
      expect(listener).to receive(:found_carrier_member_id).with('1234')
      expect(validator.validate(person_loop, listener, policy)).to eq true
    end
  end
end

describe Parsers::Edi::PersonLoopValidator, "given a termination on an existing policy" do
  let(:listener) { instance_double(Parsers::Edi::IncomingTransaction) }
  let(:policy_loop) { instance_double(Parsers::Edi::Etf::PolicyLoop, action: :stop, coverage_end: coverage_end) }
  let(:policy) { instance_double(Policy) }
  let(:person_loop) do
    instance_double(
      Parsers::Edi::Etf::PersonLoop,
      :carrier_member_id => nil,
      :member_id => member_id,
      :policy_loops => [policy_loop],
      :reinstate? => false
     )
  end
  let(:member_id) { "the member id" }
  let(:enrollee) { instance_double(Enrollee, :coverage_start => coverage_start) }
  let(:coverage_start) { Date.new(2016,1,1) }
  let(:expiration_date) { Date.new(2016,12,31) }
  let(:coverage_year) { (coverage_start..expiration_date) }

  let(:validator) { Parsers::Edi::PersonLoopValidator.new }

  before :each do
    allow(policy).to receive(:enrollee_for_member_id).with(member_id).and_return(enrollee)
  end

  context "when an expiration date can not be determined" do
    let(:coverage_end) { "20161231" }

    before :each do
      allow(policy).to receive(:coverage_year).and_raise(NoMethodError.new("plan year missing from DB"))
    end

    it "notifies the listener of the unknown expiration date" do
      expect(listener).to receive(:indeterminate_policy_expiration).with({:member_id=>member_id})
      expect(validator.validate(person_loop, listener, policy)).to be_falsey
    end
  end

  context "with a termination date after the natural policy expiration" do
    let(:coverage_end) { "20170101" }

    before :each do
      allow(policy).to receive(:coverage_year).and_return(coverage_year)
    end

    it "notifies the listener of the invalid_termination_date" do
      expect(listener).to receive(:termination_date_after_expiration).with({:coverage_end=>coverage_end, :expiration_date=>"20161231", :member_id=>member_id})
      expect(validator.validate(person_loop, listener, policy)).to be_falsey
    end
  end

  context "with a termination date that is equal to the natural policy expiration" do
    let(:coverage_end) { "20161231" }

    before :each do
      allow(policy).to receive(:is_shop?).and_return(false)
      allow(policy).to receive(:coverage_year).and_return(coverage_year)
    end

    it "notifies the listener of the invalid_termination_date" do
      expect(validator.validate(person_loop, listener, policy)).to be_truthy
    end
  end
end

describe Parsers::Edi::PersonLoopValidator, "given an inbound reinstatement" do
  let(:listener) do
    instance_double(
      Parsers::Edi::IncomingTransaction
    )
  end

  let(:policy) do
    instance_double(
      Policy,
      coverage_year: coverage_year,
      is_shop?: false
    )
  end

  let(:person_loop) do
    instance_double(
      Parsers::Edi::Etf::PersonLoop,
      {
        :carrier_member_id => nil,
        :member_id => member_id,
        :policy_loops => [policy_loop],
        :reinstate? => true
      }
    )
  end

  let(:member_id) { "the member id" }
  let(:enrollee) { instance_double(Enrollee, :coverage_start => coverage_start) }
  let(:coverage_start) { Date.new(2016,1,1) }
  let(:coverage_end) { "20161231" }
  let(:expiration_date) { Date.new(2016,12,31) }
  let(:coverage_year) { (coverage_start..expiration_date) }
  let(:policy_loop) { instance_double(Parsers::Edi::Etf::PolicyLoop, action: :stop, coverage_end: coverage_end) }

  let(:validator) { Parsers::Edi::PersonLoopValidator.new }

  before :each do
    allow(policy).to receive(:enrollee_for_member_id).with(member_id).and_return(enrollee)
  end

  it "is not valid because of being a reinstate" do
    expect(listener).to receive(:inbound_reinstate_blocked)
    expect(validator.validate(person_loop, listener, policy)).to be_falsey
  end
end