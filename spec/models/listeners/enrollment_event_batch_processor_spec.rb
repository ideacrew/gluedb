require 'rails_helper'

describe Listeners::EnrollmentEventBatchProcessor, :dbclean => :after_each do
  let(:connection) { double }
  let(:queue) { double }
  let(:default_exchange) { double }
  let(:fanout) { double }
  let(:channel) { double(:connection => connection, fanout: fanout, :default_exchange => default_exchange) }
  let(:event_broadcaster) { instance_double(Amqp::EventBroadcaster) }
  let(:event_exchange_name) { "event exchange name" }
  let(:body) { "" }
  let(:batch) { EnrollmentEvents::Batch.create(aasm_state: 'pending_transmission') }
  let(:delivery_tag) { double }
  let(:delivery_info) { double(delivery_tag: delivery_tag, routing_key: nil) }
  let(:processing_client) { double }
  let(:exception) {StandardError.new}

  subject { Listeners::EnrollmentEventBatchProcessor.new(channel, queue) }

  context "given batch_id on message" do
    let(:properties) do
      double(
          headers: { batch_id: batch.id }
      )
    end
    before(:each) do
      allow(channel).to receive(:ack).with(delivery_tag, false)
      allow(Amqp::EventBroadcaster).to receive(:new).with(connection).and_return(event_broadcaster)
      @time_now = Time.now
      allow(Time).to receive(:now).and_return(@time_now)
      allow(event_broadcaster).to receive(:broadcast).with({
                                                               :routing_key => "info.application.glue.enrollment_event_batch_processor.batch_processed",
                                                               :headers=> {
                                                                   :batch_id => batch.id,
                                                                   :return_status => "200",
                                                                   :submitted_timestamp=> @time_now,
                                                               }
                                                           }, body
                                  )
    end

    it "acknowledges the message" do
      expect(channel).to receive(:ack).with(delivery_tag, false)
      subject.on_message(delivery_info, properties, "")
    end

    it "should broadcast batch processed message" do
      expect(event_broadcaster).to receive(:broadcast).with({
                                                                :routing_key => "info.application.glue.enrollment_event_batch_processor.batch_processed",
                                                                :headers=> {
                                                                    :batch_id => batch.id,
                                                                    :return_status => "200",
                                                                    :submitted_timestamp=> @time_now
                                                                }
                                                            }, body)
      subject.on_message(delivery_info, properties, body)
    end

    it "should updated batch to closed" do
      subject.on_message(delivery_info, properties, "")
      batch.reload
      expect(batch.aasm_state).to eq "closed"
    end
  end

  context "given with no batch_id on message" do
    let(:properties) do
      double(
          headers: { batch_id: "1" }
      )
    end
    before(:each) do
      allow(channel).to receive(:ack).with(delivery_tag, false)
      allow(Amqp::EventBroadcaster).to receive(:new).with(connection).and_return(event_broadcaster)
      @time_now = Time.now
      allow(Time).to receive(:now).and_return(@time_now)
      allow(event_broadcaster).to receive(:broadcast).with({
                                                               :routing_key => "info.application.glue.enrollment_event_batch_processor.batch_not_found",
                                                               :headers=> {
                                                                   :batch_id => "1",
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
                                                                :routing_key => "info.application.glue.enrollment_event_batch_processor.batch_not_found",
                                                                :headers=> {
                                                                    :batch_id => "1",
                                                                    :return_status => "404",
                                                                    :submitted_timestamp=> @time_now
                                                                }
                                                            }, body)
      subject.on_message(delivery_info, properties, body)
    end
  end

  context "exception raised when processing batch" do
    let(:body) { "backtrace_entry" }
    let(:properties) do
      double(
          headers: { batch_id: batch.id }
      )
    end

    before(:each) do
      allow(channel).to receive(:ack).with(delivery_tag, false)
      allow(EnrollmentEventProcessingClient).to receive(:new).and_return(processing_client)
      allow(processing_client).to receive(:call).with([]).and_raise(exception)
      allow(exception).to receive(:backtrace).and_return(body)
      allow(Amqp::EventBroadcaster).to receive(:new).with(connection).and_return(event_broadcaster)
      @time_now = Time.now
      allow(Time).to receive(:now).and_return(@time_now)
      allow(event_broadcaster).to receive(:broadcast).with({
                                                               :routing_key => "error.application.glue.enrollment_event_batch_processor.exception",
                                                               :headers=> {
                                                                   :batch_id => batch.id,
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
                                                                :routing_key => "error.application.glue.enrollment_event_batch_processor.exception",
                                                                :headers=> {
                                                                    :batch_id => batch.id,
                                                                    :return_status => "500",
                                                                    :submitted_timestamp=> @time_now
                                                                }
                                                            }, body)
      subject.on_message(delivery_info, properties, body)
    end

    it "should updated batch to error" do
      subject.on_message(delivery_info, properties, "")
      batch.reload
      expect(batch.aasm_state).to eq "error"
    end
  end
end