require 'rails_helper'
describe Parsers::Edi::IncomingTransaction, :dbclean => :after_each do
  let(:enrollee) { Enrollee.new(m_id: '1',
                                relationship_status_code: 'self',
                                employment_status_code: 'active',
                                benefit_status_code: 'active',
                                coverage_start: coverage_start,
                                coverage_end: coverage_end ) }
  let(:policy) do
    policy = Policy.new(eg_id: '7899', plan_id: '1')
    policy.enrollees << enrollee
    policy.save!
    policy
  end

  let(:coverage_start) { '20140501' }
  let(:coverage_end) { '20140501' }

  let(:policy_loop) { double(id: '4321', action: :stop, coverage_end: coverage_end) }
  let(:person_loop) { instance_double(Parsers::Edi::Etf::PersonLoop, member_id: '1', carrier_member_id: '1234', policy_loops: [policy_loop], :non_payment_change? => false) }
  let(:etf) { double(people: [person_loop], is_shop?: false) }
  let(:incoming) do
    incoming = Parsers::Edi::IncomingTransaction.new(etf)
    incoming.policy_found(policy)
    incoming
  end

  let(:event_broadcaster) { instance_double(Amqp::EventBroadcaster) }

  before :each do
    allow(Amqp::EventBroadcaster).to receive(:with_broadcaster).and_yield(event_broadcaster)
    allow(event_broadcaster).to receive(:broadcast).with({
          :routing_key => "info.events.policy.canceled",
          :headers => {
            :resource_instance_uri => policy.eg_id,
            :event_effective_date => policy.policy_end.strftime("%Y%m%d"),
            :hbx_enrollment_ids => JSON.dump(policy.hbx_enrollment_ids)
          }
    }, "")
    allow(Observers::PolicyUpdated).to receive(:notify).with(policy)
  end

  it 'imports enrollee carrier member id' do
    incoming.import

    enrollee.reload
    expect(enrollee.c_id).to eq person_loop.carrier_member_id
  end

  it 'imports enrollee carrier policy id' do
    incoming.import

    enrollee.reload
    expect(enrollee.cp_id).to eq policy_loop.id
  end

  context 'when action policy action is stop' do
    it 'sets enrollee coverage status to inactive' do
      incoming.import

      enrollee.reload
      expect(enrollee.coverage_status).to eq 'inactive'
    end

    it 'imports enrollee coverage-end date' do
      incoming.import

      enrollee.reload
      expect(enrollee.coverage_end.strftime("%Y%m%d")).to eq policy_loop.coverage_end
    end

    context 'when coverage start/end are different' do
      let(:coverage_start) { '20140501' }
      let(:coverage_end) { '20140706' }
      before :each do
        allow(event_broadcaster).to receive(:broadcast).with({
          :routing_key => "info.events.policy.terminated",
          :headers => {
            :resource_instance_uri => policy.eg_id,
            :event_effective_date => policy.policy_end.strftime("%Y%m%d"),
            :hbx_enrollment_ids => JSON.dump(policy.hbx_enrollment_ids)
          }
        }, "")
      end

      it "sends the termination notice" do
        expect(event_broadcaster).to receive(:broadcast).with({
          :routing_key => "info.events.policy.terminated",
          :headers => {
            :resource_instance_uri => policy.eg_id,
            :event_effective_date => policy.policy_end.strftime("%Y%m%d"),
            :hbx_enrollment_ids => JSON.dump(policy.hbx_enrollment_ids)
          }
        }, "")
        incoming.import
      end

      it 'sets the policy to terminated' do
        incoming.import

        expect(enrollee.policy.aasm_state).to eq 'terminated'
        expect(policy.aasm_state).to eq 'terminated'
      end

      it 'notifies of policy termination' do
        expect(Observers::PolicyUpdated).to receive(:notify).with(policy)
        incoming.import
      end
    end

    context 'when coverage start/end are different, and the reason is non-payment' do
      let(:coverage_start) { '20140501' }
      let(:coverage_end) { '20140706' }
      let(:person_loop) { instance_double(Parsers::Edi::Etf::PersonLoop, member_id: '1', carrier_member_id: '1234', policy_loops: [policy_loop], :non_payment_change? => true) }
      before :each do
        allow(event_broadcaster).to receive(:broadcast).with({
          :routing_key => "info.events.policy.terminated",
          :headers => {
            :resource_instance_uri => policy.eg_id,
            :event_effective_date => policy.policy_end.strftime("%Y%m%d"),
            :hbx_enrollment_ids => JSON.dump(policy.hbx_enrollment_ids),
            :qualifying_reason => "urn:openhbx:terms:v1:benefit_maintenance#non_payment"
          }
        }, "")
      end

      it "sends the termination notice" do
        expect(event_broadcaster).to receive(:broadcast).with({
          :routing_key => "info.events.policy.terminated",
          :headers => {
            :resource_instance_uri => policy.eg_id,
            :event_effective_date => policy.policy_end.strftime("%Y%m%d"),
            :hbx_enrollment_ids => JSON.dump(policy.hbx_enrollment_ids),
            :qualifying_reason => "urn:openhbx:terms:v1:benefit_maintenance#non_payment"
          }
        }, "")
        incoming.import
      end

      it 'sets the policy to terminated' do
        incoming.import

        expect(enrollee.policy.aasm_state).to eq 'terminated'
        expect(policy.aasm_state).to eq 'terminated'
      end
    end

    context 'when coverage start/end are the same' do
      let(:coverage_start) { '20140501' }
      let(:coverage_end) { '20140501' }

      it "broadcasts the cancel" do
        expect(event_broadcaster).to receive(:broadcast).with({
          :routing_key => "info.events.policy.canceled",
          :headers => {
            :resource_instance_uri => policy.eg_id,
            :event_effective_date => policy.policy_end.strftime("%Y%m%d"),
            :hbx_enrollment_ids => JSON.dump(policy.hbx_enrollment_ids)
          }
        }, "")
        incoming.import
      end

      it 'sets the policy to canceled' do
        incoming.import

        expect(enrollee.policy.aasm_state).to eq 'canceled'
        expect(policy.aasm_state).to eq 'canceled'
      end

      it 'notifies of policy cancelation' do
        expect(Observers::PolicyUpdated).to receive(:notify).with(policy)
        incoming.import
      end
    end
  end
end

context '_term_enrollee_on_subscriber_term', :dbclean => :after_each do
  let(:eg_id) { '987' }
  let(:carrier_id) { '2' }
  let(:kind) { 'individual' }
  let(:carrier) { Carrier.create }
  let(:active_plan) { Plan.create!(:name => "test_plan", carrier_id: carrier_id, :coverage_type => "health", year: Date.today.year) }
  let!(:primary) {
    person = FactoryGirl.create :person
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }
  let!(:dep) {
    person = FactoryGirl.create :person
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }
  let!(:dep2) {
    person = FactoryGirl.create :person
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }
  let(:prim_coverage_start) { Date.today.beginning_of_year }
  let(:subscriber_enrollee) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start: prim_coverage_start, coverage_end: prim_coverage_end, :c_id => nil, :cp_id => nil)}
  let(:child_enrollee1) { Enrollee.new(m_id: dep.authority_member.hbx_member_id, rel_code: 'child', coverage_start: child1_coverage_start, coverage_end: child1_coverage_end, :c_id => nil, :cp_id => nil)}
  let(:child_enrollee2) { Enrollee.new(m_id: dep2.authority_member.hbx_member_id, rel_code: 'child', coverage_start: child2_coverage_start, coverage_end: child2_coverage_end, :c_id => nil, :cp_id => nil)}
  let(:aptc_credit) { AptcCredit.new(start_on: prim_coverage_start, end_on: Date.new(prim_coverage_start.year, 12, 31), aptc: 100.0, pre_amt_tot: 200.0, tot_res_amt: 100.0) }
  let!(:active_policy) {
    policy =  FactoryGirl.create(:policy, enrollment_group_id: eg_id, hbx_enrollment_ids: [eg_id], carrier_id: carrier_id, plan: active_plan, carrier: carrier, coverage_start: prim_coverage_start, coverage_end: nil, kind: kind)
    policy.update_attributes(enrollees: [subscriber_enrollee, child_enrollee1, child_enrollee2])
    policy.aptc_credits = [aptc_credit]
    policy.save
    policy
  }
  let(:policy_loop) { double(id: eg_id, action: :stop, coverage_end: coverage_end) }
  let(:person_loop) { instance_double(Parsers::Edi::Etf::PersonLoop, member_id: primary.authority_member.hbx_member_id, carrier_member_id: '1234', policy_loops: [policy_loop], :non_payment_change? => false) }
  let(:etf) { double(people: [person_loop], is_shop?: false) }
  let(:incoming) do
    incoming = Parsers::Edi::IncomingTransaction.new(etf)
    incoming.policy_found(active_policy)
    incoming
  end
  let(:event_broadcaster) { instance_double(Amqp::EventBroadcaster) }
  before :each do
    allow(Amqp::EventBroadcaster).to receive(:with_broadcaster).and_yield(event_broadcaster)
    allow(event_broadcaster).to receive(:broadcast).with({
                                                           :routing_key => "info.events.policy.terminated",
                                                           :headers => {
                                                             :resource_instance_uri => active_policy.eg_id,
                                                             :event_effective_date => active_policy.policy_end.try(:strftime, "%Y%m%d"),
                                                             :hbx_enrollment_ids => JSON.dump(active_policy.hbx_enrollment_ids)
                                                           }
                                                         }, "")
    allow(Observers::PolicyUpdated).to receive(:notify).with(active_policy)
  end

  context "when enrollee have coverage end date" do
    context "when member end date greater than subscriber end date" do
      let(:prim_coverage_end) { (Date.today.beginning_of_year + 2.months).end_of_month }

      let(:child1_coverage_start) { Date.today.beginning_of_year  }
      let(:child1_coverage_end) { (Date.today.beginning_of_year + 3.months).end_of_month  }

      let(:child2_coverage_start) { Date.today.beginning_of_year }
      let(:child2_coverage_end) { (Date.today.beginning_of_year + 3.months).end_of_month }

      let(:coverage_end) { prim_coverage_end.strftime("%Y%m%d") }

      it "should update member to match subscriber end date" do
        # Before importing EDI
        expect(child_enrollee1.coverage_end).to eq child1_coverage_end
        expect(child_enrollee1.termed_by_carrier).to eq false
        expect(child_enrollee2.coverage_end).to eq child2_coverage_end
        expect(child_enrollee2.termed_by_carrier).to eq false
        incoming.import
        # After importing EDI
        active_policy.reload
        policy = Policy.where(eg_id: active_policy.eg_id).first
        expect(policy.policy_end).to eq prim_coverage_end

        expect(policy.enrollees.where(m_id: child_enrollee1.m_id).first.coverage_end).to eq prim_coverage_end
        expect(policy.enrollees.where(m_id: child_enrollee1.m_id).first.termed_by_carrier).to eq true
        expect(policy.enrollees.where(m_id: child_enrollee2.m_id).first.coverage_end).to eq prim_coverage_end
        expect(policy.enrollees.where(m_id: child_enrollee2.m_id).first.termed_by_carrier).to eq true
        # update aptc credit to match subscriber end date
        expect(policy.aptc_credits.count).to eq 1
        expect(policy.aptc_credits[0].end_on).to eq prim_coverage_end
      end
    end

    context "when member start and end date greater than subscriber end date and member canceled" do
      let(:prim_coverage_end) { (Date.today.beginning_of_year + 2.months).end_of_month }

      let(:child1_coverage_start) { Date.today.beginning_of_year + 3.months  }
      let(:child1_coverage_end) { Date.today.beginning_of_year + 3.months  }

      let(:child2_coverage_start) { Date.today.beginning_of_year + 3.months }
      let(:child2_coverage_end) { Date.today.beginning_of_year + 3.months }

      let(:coverage_end) { prim_coverage_end.strftime("%Y%m%d") }


      it "should not update member end date to match subscriber end date" do
        # Before importing EDI
        expect(child_enrollee1.coverage_start).to eq child1_coverage_start
        expect(child_enrollee1.termed_by_carrier).to eq false
        expect(child_enrollee1.coverage_end).to eq child1_coverage_start
        expect(child_enrollee2.termed_by_carrier).to eq false

        expect(child_enrollee1.coverage_start).to eq child2_coverage_start
        expect(child_enrollee2.coverage_end).to eq child2_coverage_start

        incoming.import
        # After importing EDI
        active_policy.reload
        policy = Policy.where(eg_id: active_policy.eg_id).first
        expect(policy.policy_end).to eq prim_coverage_end

        expect(policy.enrollees.where(m_id: child_enrollee1.m_id).first.coverage_end).to eq child1_coverage_end
        expect(policy.enrollees.where(m_id: child_enrollee1.m_id).first.termed_by_carrier).to eq false
        expect(policy.enrollees.where(m_id: child_enrollee2.m_id).first.coverage_end).to eq child2_coverage_end
        expect(policy.enrollees.where(m_id: child_enrollee2.m_id).first.termed_by_carrier).to eq false

        # update aptc credit to match subscriber end date
        expect(policy.aptc_credits.count).to eq 1
        expect(policy.aptc_credits[0].end_on).to eq prim_coverage_end
      end
    end

    context "when member start date and end date greater than subscriber end date and member terminated" do
      let(:prim_coverage_end) { (Date.today.beginning_of_year + 2.months).end_of_month }

      let(:child1_coverage_start) { Date.today.beginning_of_year + 3.months  }
      let(:child1_coverage_end) { Date.today.beginning_of_year + 6.months  }

      let(:child2_coverage_start) { Date.today.beginning_of_year + 3.months }
      let(:child2_coverage_end) { Date.today.beginning_of_year + 6.months }

      let(:coverage_end) { prim_coverage_end.strftime("%Y%m%d") }


      it "should update member end date to match member start date" do
        # Before importing EDI
        expect(child_enrollee1.coverage_start).to eq child1_coverage_start
        expect(child_enrollee1.coverage_end).to eq child1_coverage_end

        expect(child_enrollee1.coverage_start).to eq child2_coverage_start
        expect(child_enrollee2.coverage_end).to eq child2_coverage_end

        incoming.import
        # After importing EDI
        active_policy.reload
        policy = Policy.where(eg_id: active_policy.eg_id).first
        expect(policy.policy_end).to eq prim_coverage_end
        expect(policy.enrollees.where(m_id: child_enrollee1.m_id).first.coverage_end).to eq child1_coverage_start
        expect(policy.enrollees.where(m_id: child_enrollee2.m_id).first.coverage_end).to eq child2_coverage_start

        # update aptc credit to match subscriber end date
        expect(policy.aptc_credits.count).to eq 1
        expect(policy.aptc_credits[0].end_on).to eq prim_coverage_end
      end
    end
  end

  context "when enrollee has no coverage end date" do
    context "when member start date before subscriber end date" do
      let(:prim_coverage_end) { (Date.today.beginning_of_year + 2.months).end_of_month }

      let(:child1_coverage_start) { Date.today.beginning_of_year  }
      let(:child1_coverage_end) { nil  }

      let(:child2_coverage_start) { Date.today.beginning_of_year }
      let(:child2_coverage_end) { nil }

      let(:coverage_end) { prim_coverage_end.strftime("%Y%m%d") }

      it "should terminate member with subscriber end date" do
        # Before importing EDI
        expect(child_enrollee1.coverage_end).to eq nil
        expect(child_enrollee1.termed_by_carrier).to eq false
        expect(child_enrollee2.coverage_end).to eq nil
        expect(child_enrollee2.termed_by_carrier).to eq false
        incoming.import
        # After importing EDI
        active_policy.reload
        policy = Policy.where(eg_id: active_policy.eg_id).first
        expect(policy.policy_end).to eq prim_coverage_end

        expect(policy.enrollees.where(m_id: child_enrollee1.m_id).first.coverage_end).to eq prim_coverage_end
        expect(policy.enrollees.where(m_id: child_enrollee1.m_id).first.termed_by_carrier).to eq true

        expect(policy.enrollees.where(m_id: child_enrollee2.m_id).first.coverage_end).to eq prim_coverage_end
        expect(policy.enrollees.where(m_id: child_enrollee2.m_id).first.termed_by_carrier).to eq true
      end

      it "should update aptc credits to match subscriber end date" do
        # Before importing EDI
        expect(active_policy.aptc_credits.count).to eq 1
        expect(active_policy.aptc_credits[0].end_on).to eq Date.new(prim_coverage_start.year, 12, 31) # credit end date greater policy end date

        incoming.import
        # After importing EDI
        active_policy.reload
        policy = Policy.where(eg_id: active_policy.eg_id).first
        expect(policy.aptc_credits.count).to eq 1
        expect(policy.aptc_credits[0].end_on).to eq prim_coverage_end
      end
    end

    context "when member start greater than subscriber end date" do
      let(:prim_coverage_end) { (Date.today.beginning_of_year + 2.months).end_of_month }

      let(:child1_coverage_start) { Date.today.beginning_of_year + 3.months  }
      let(:child1_coverage_end) { nil  }

      let(:child2_coverage_start) { Date.today.beginning_of_year + 3.months }
      let(:child2_coverage_end) { nil }

      let(:coverage_end) { prim_coverage_end.strftime("%Y%m%d") }
      let(:aptc_credit1) { AptcCredit.new(start_on: prim_coverage_start, end_on: child1_coverage_start - 1.day, aptc: 100.0, pre_amt_tot: 200.0, tot_res_amt: 100.0) }
      let(:aptc_credit2) { AptcCredit.new(start_on: child1_coverage_start, end_on: Date.new(child1_coverage_start.year, 12, 31), aptc: 100.0, pre_amt_tot: 200.0, tot_res_amt: 100.0) }

      before do
        active_policy.aptc_credits = [aptc_credit1, aptc_credit2]
        active_policy.save
      end

      it "should cancel member coverage and update end date of member to start date of member" do
        # Before importing EDI
        expect(child_enrollee1.coverage_start).to eq child1_coverage_start
        expect(child_enrollee1.coverage_end).to eq nil

        expect(child_enrollee1.coverage_start).to eq child2_coverage_start
        expect(child_enrollee2.coverage_end).to eq nil

        incoming.import
        # After importing EDI
        active_policy.reload
        policy = Policy.where(eg_id: active_policy.eg_id).first
        expect(policy.policy_end).to eq prim_coverage_end
        expect(policy.enrollees.where(m_id: child_enrollee1.m_id).first.coverage_end).to eq child1_coverage_start
        expect(policy.enrollees.where(m_id: child_enrollee1.m_id).first.termed_by_carrier).to eq true
        expect(policy.enrollees.where(m_id: child_enrollee2.m_id).first.coverage_end).to eq child2_coverage_start
        expect(policy.enrollees.where(m_id: child_enrollee2.m_id).first.termed_by_carrier).to eq true
      end

      it "should aptc credits end date to match policy end date and delete future credits" do
        # Before importing EDI
        expect(active_policy.aptc_credits.count).to eq 2
        expect(active_policy.aptc_credits[0].end_on).to eq prim_coverage_end # credit matching subscriber end date
        expect(active_policy.aptc_credits[1].end_on).to eq Date.new(child1_coverage_start.year, 12, 31) # future credit

        incoming.import
        # After importing EDI
        active_policy.reload
        policy = Policy.where(eg_id: active_policy.eg_id).first
        expect(policy.aptc_credits.count).to eq 1
        expect(policy.aptc_credits[0].end_on).to eq prim_coverage_end
      end
    end
  end
end