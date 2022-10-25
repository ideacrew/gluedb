require 'rails_helper'

describe Listeners::EnrollmentBrokerUpdatedListener, :dbclean => :after_each do
  let(:connection) { double }
  let(:queue) { double }
  let(:default_exchange) { double }
  let(:fanout) { double }
  let(:channel) { double(:connection => connection, fanout: fanout, :default_exchange => default_exchange) }
  let(:event_broadcaster) { instance_double(Amqp::EventBroadcaster) }
  let(:event_exchange_name) { "event exchange name" }
  let(:body) { "" }
  let(:delivery_tag) { double }
  let(:delivery_info) { double(delivery_tag: delivery_tag, routing_key: nil) }
  let(:processing_client) { double }
  let(:exception) {StandardError.new}
  let(:broker) { FactoryGirl.create(:broker) }
  let!(:calendar_year) {Date.today.year - 1}
  let(:person) {FactoryGirl.create(:person)}
  let(:member) {person.members.first}
  let(:carrier) { FactoryGirl.create(:carrier) }
  let(:plan) { FactoryGirl.create(:plan, carrier: carrier, year: 2022, coverage_type: "health", hios_plan_id: "1212") }
  let!(:policy) { Policy.new(eg_id: '1', enrollees: [enrollee1], plan: plan, carrier: carrier, pre_amt_tot: "100.00", tot_res_amt: "100.00") }
  let!(:enrollee1) do
    Enrollee.new(
      m_id: member.hbx_member_id,
      benefit_status_code: 'active',
      employment_status_code: 'active',
      relationship_status_code: 'self',
      coverage_start: Date.new(calendar_year,1,1),
      pre_amt: "100.00")
  end

  before :each do
    person.update_attributes!(:authority_member_id => person.members.first.hbx_member_id)
    policy.save!
  end

  subject { Listeners::EnrollmentBrokerUpdatedListener.new(channel, queue) }

  context "given hbx_enrollment_id on message" do
    let(:properties) do
      double(
          headers: { hbx_enrollment_id: policy.eg_id, new_broker_npn: broker.npn }
      )
    end

    before(:each) do
      allow(subject).to receive(:publish_to_edi).with(policy).and_return(true)
      allow(channel).to receive(:ack).with(delivery_tag, false)
      allow(Amqp::EventBroadcaster).to receive(:new).with(connection).and_return(event_broadcaster)
      @time_now = Time.now
      allow(Time).to receive(:now).and_return(@time_now)
      allow(event_broadcaster).to receive(:broadcast).with({
                                                              :routing_key => "info.application.glue.enrollment_broker_updated_listener.broker_policy_processed",
                                                              :headers=> {
                                                                :hbx_enrollment_id => policy.eg_id,
                                                                :new_broker_npn => broker.npn,
                                                                :return_status => "200",
                                                                :submitted_timestamp=> @time_now,
                                                              }
                                                           }, body)
    end

    it "acknowledges the message" do
      expect(channel).to receive(:ack).with(delivery_tag, false)
      subject.on_message(delivery_info, properties, "")
    end

    it "should broadcast broker policy processed message" do
      expect(event_broadcaster).to receive(:broadcast).with({
                                                                :routing_key => "info.application.glue.enrollment_broker_updated_listener.broker_policy_processed",
                                                                :headers=> {
                                                                    :hbx_enrollment_id => policy.eg_id,
                                                                    :new_broker_npn => broker.npn,
                                                                    :return_status => "200",
                                                                    :submitted_timestamp=> @time_now
                                                                }
                                                            }, body)
      subject.on_message(delivery_info, properties, body)
    end
  end

  context "given with terminated policy on message" do
    let(:properties) do
      double(
          headers: { hbx_enrollment_id: policy.eg_id, new_broker_npn: broker.npn }
      )
    end
    let!(:enrollee1) do
      Enrollee.new(
        m_id: member.hbx_member_id,
        benefit_status_code: 'active',
        employment_status_code: 'active',
        relationship_status_code: 'self',
        coverage_start: Date.new(calendar_year,1,1),
        coverage_end: Date.new(calendar_year,12,31),
        pre_amt: "100.00")
    end

    before(:each) do
      allow(channel).to receive(:ack).with(delivery_tag, false)
      allow(Amqp::EventBroadcaster).to receive(:new).with(connection).and_return(event_broadcaster)
      @time_now = Time.now
      allow(Time).to receive(:now).and_return(@time_now)
      allow(event_broadcaster).to receive(:broadcast).with({
                                                              :routing_key => "info.application.glue.enrollment_broker_updated_listener.broker_policy_terminated",
                                                              :headers=> {
                                                                :hbx_enrollment_id => policy.eg_id,
                                                                :new_broker_npn => broker.npn,
                                                                :return_status => "404",
                                                                :submitted_timestamp=> @time_now,
                                                               }
                                                           }, body)
    end

    it "acknowledges the message" do
      expect(channel).to receive(:ack).with(delivery_tag, false)
      subject.on_message(delivery_info, properties, "")
    end

    it "should broadcast broker policy is terminated on message" do
      expect(event_broadcaster).to receive(:broadcast).with({
                                                              :routing_key => "info.application.glue.enrollment_broker_updated_listener.broker_policy_terminated",
                                                              :headers=> {
                                                                :hbx_enrollment_id => policy.eg_id,
                                                                :new_broker_npn => broker.npn,
                                                                :return_status => "404",
                                                                :submitted_timestamp=> @time_now,
                                                               }
                                                           }, body)
      subject.on_message(delivery_info, properties, body)
    end
  end


  context "given with npn no broker found on message" do
    let(:properties) do
      double(
          headers: { hbx_enrollment_id: policy.eg_id, new_broker_npn: "random npn" }
      )
    end

    before(:each) do
      allow(channel).to receive(:ack).with(delivery_tag, false)
      allow(Amqp::EventBroadcaster).to receive(:new).with(connection).and_return(event_broadcaster)
      @time_now = Time.now
      allow(Time).to receive(:now).and_return(@time_now)
      allow(event_broadcaster).to receive(:broadcast).with({
                                                              :routing_key => "info.application.glue.enrollment_broker_updated_listener.broker_not_found",
                                                              :headers=> {
                                                                :hbx_enrollment_id => policy.eg_id,
                                                                :new_broker_npn => "random npn",
                                                                :return_status => "404",
                                                                :submitted_timestamp=> @time_now,
                                                               }
                                                           }, body)
    end

    it "acknowledges the message" do
      expect(channel).to receive(:ack).with(delivery_tag, false)
      subject.on_message(delivery_info, properties, "")
    end

    it "should broadcast broker is not found message" do
      expect(event_broadcaster).to receive(:broadcast).with({
                                                              :routing_key => "info.application.glue.enrollment_broker_updated_listener.broker_not_found",
                                                              :headers=> {
                                                                :hbx_enrollment_id => policy.eg_id,
                                                                :new_broker_npn => "random npn",
                                                                :return_status => "404",
                                                                :submitted_timestamp=> @time_now,
                                                               }
                                                           }, body)
      subject.on_message(delivery_info, properties, body)
    end
  end

  context "given with hbx_enrollment_id no policy on message" do
    let(:properties) do
      double(
          headers: { hbx_enrollment_id: "random id", new_broker_npn: broker.npn }
      )
    end

    before(:each) do
      allow(channel).to receive(:ack).with(delivery_tag, false)
      allow(Amqp::EventBroadcaster).to receive(:new).with(connection).and_return(event_broadcaster)
      @time_now = Time.now
      allow(Time).to receive(:now).and_return(@time_now)
      allow(event_broadcaster).to receive(:broadcast).with({
                                                              :routing_key => "info.application.glue.enrollment_broker_updated_listener.policy_not_found",
                                                              :headers=> {
                                                                :hbx_enrollment_id => "random id",
                                                                :new_broker_npn => broker.npn,
                                                                :return_status => "404",
                                                                :submitted_timestamp=> @time_now,
                                                               }
                                                           }, body)
    end

    it "acknowledges the message" do
      expect(channel).to receive(:ack).with(delivery_tag, false)
      subject.on_message(delivery_info, properties, "")
    end

    it "should broadcast batch not found message" do
      expect(event_broadcaster).to receive(:broadcast).with({
                                                              :routing_key => "info.application.glue.enrollment_broker_updated_listener.policy_not_found",
                                                              :headers=> {
                                                                :hbx_enrollment_id => "random id",
                                                                :new_broker_npn => broker.npn,
                                                                :return_status => "404",
                                                                :submitted_timestamp=> @time_now,
                                                               }
                                                           }, body)
      subject.on_message(delivery_info, properties, body)
    end
  end

  context "given hbx_enrollment_id, policy with given hbx_enrollment_id has error on message" do
    let(:properties) do
      double(
          headers: { hbx_enrollment_id: policy.eg_id, new_broker_npn: broker.npn }
      )
    end

    before(:each) do
      allow(channel).to receive(:ack).with(delivery_tag, false)
      allow(subject).to receive(:publish_to_edi).with(policy).and_raise(exception)
      allow(exception).to receive(:backtrace).and_return(body)
      allow(Amqp::EventBroadcaster).to receive(:new).with(connection).and_return(event_broadcaster)
      @time_now = Time.now
      allow(Time).to receive(:now).and_return(@time_now)
      allow(event_broadcaster).to receive(:broadcast).with({
                                                              :routing_key => "error.application.glue.enrollment_broker_updated_listener.exception",
                                                              :headers=> {
                                                                :hbx_enrollment_id => policy.eg_id,
                                                                :new_broker_npn => broker.npn,
                                                                :return_status => "500",
                                                                :submitted_timestamp=> @time_now,
                                                              }
                                                           }, body)
    end

    it "acknowledges the message" do
      expect(channel).to receive(:ack).with(delivery_tag, false)
      subject.on_message(delivery_info, properties, "")
    end

    it "should broadcast exception message" do
      expect(event_broadcaster).to receive(:broadcast).with({
                                                                :routing_key => "error.application.glue.enrollment_broker_updated_listener.exception",
                                                                :headers=> {
                                                                    :hbx_enrollment_id => policy.eg_id,
                                                                    :new_broker_npn => broker.npn,
                                                                    :return_status => "500",
                                                                    :submitted_timestamp=> @time_now
                                                                }
                                                            }, body)
      subject.on_message(delivery_info, properties, body)
    end
  end
end