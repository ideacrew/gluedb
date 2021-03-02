require 'rails_helper'

describe Listeners::EnrollmentEventBatchHandler, :dbclean => :after_each do
  let(:connection) { double }
  let(:queue) { double }
  let(:default_exchange) { double }
  let(:topic) { double }
  let(:channel) { double(:connection => connection, topic: topic, :default_exchange => default_exchange) }
  let(:event_broadcaster) { instance_double(Amqp::EventBroadcaster) }
  let(:event_exchange_name) { "event exchange name" }

  subject { Listeners::EnrollmentEventBatchHandler.new(channel, queue) }

  context "given an SHOP enrollment message" do
    let(:employer_hbx_id) { 1 }
    let(:subscriber_hbx_id) { 1 }
    let(:delivery_tag) { double }
    let(:delivery_info) { double(delivery_tag: delivery_tag, routing_key: nil) }
    let(:headers) {double}
    let(:event_time) { Time.now }
    let(:properties) do
      double(
          headers: headers,
          timestamp: event_time
      )
    end
    let(:body) { <<-EVENTXML
      <enrollment_event xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='http://openhbx.org/api/terms/1.0'>
      <header>
        <hbx_id>29035</hbx_id>
        <submitted_timestamp>2016-11-08T17:44:49</submitted_timestamp>
      </header>
      <event>
        <body>
          <enrollment_event_body xmlns="http://openhbx.org/api/terms/1.0">
            <affected_members>
            </affected_members>
            <enrollment xmlns="http://openhbx.org/api/terms/1.0">
              <policy>
                <id>
                  <id>123</id>
                </id>
                <enrollees>
                  <enrollee>
                    <member>
                      <id><id>#{subscriber_hbx_id}</id></id>
                    </member>
                    <is_subscriber>true</is_subscriber>
                    <benefit>
                      <premium_amount>111.11</premium_amount>
                      <begin_date>#{Date.today.next_year.beginning_of_year.strftime("%Y%m%d")}</begin_date>
                    </benefit>
                  </enrollee>
                </enrollees>
                <enrollment>
                  <individual_market>
                    <assistance_effective_date>TOTALLY BOGUS</assistance_effective_date>
                    <applied_aptc_amount>100.00</applied_aptc_amount>
                  </individual_market>
                  <shop_market>
                    <employer_link>
                      <id><id>urn:openhbx:terms:v1:employer:id##{employer_hbx_id}</id></id>
                    </employer_link>
                  </shop_market>
                  <premium_total_amount>56.78</premium_total_amount>
                  <total_responsible_amount>123.45</total_responsible_amount>
                </enrollment>
              </policy>
            </enrollment>
            </enrollment_event_body>
        </body>
      </event>
    </enrollment_event>
    EVENTXML
    }

    before(:each) do
      allow(channel).to receive(:ack).with(delivery_tag, false)
      allow(Amqp::EventBroadcaster).to receive(:new).with(connection).and_return(event_broadcaster)
      @time_now = Time.now
      allow(Time).to receive(:now).and_return(@time_now)
      allow(event_broadcaster).to receive(:broadcast).with({
        :routing_key => "info.application.glue.enrollment_event_handler.batch_created",
        :headers=> {
          :employer_hbx_id => "1",
          :subscriber_hbx_id => "1",
          :benefit_kind => "shop",
          :event_time=> "#{@time_now.to_i}",
          :return_status => "200",
          :submitted_timestamp=> @time_now }
        },
      body
      )
      allow(event_broadcaster).to receive(:broadcast).with({
        :routing_key => "info.application.glue.enrollment_event_handler.batch_transactions_updated",
        :headers=> {
          :employer_hbx_id => "1",
          :subscriber_hbx_id => "1",
          :benefit_kind => "shop",
          :event_time=> "#{@time_now.to_i}",
          :return_status => "200",
          :submitted_timestamp=> @time_now }
        },
      body
      )
    end

    it "acknowledges the message" do
      expect(channel).to receive(:ack).with(delivery_tag, false)
      subject.on_message(delivery_info, properties, body)
    end

    it "should create enrollment batch with open status" do
      expect(EnrollmentEvents::Batch.all.count).to eq 0
      expect(channel).to receive(:ack).with(delivery_tag, false)
      subject.on_message(delivery_info, properties, body)

      expect(EnrollmentEvents::Batch.all.count).to eq 1
      batch = EnrollmentEvents::Batch.first
      expect(batch.subscriber_hbx_id).to eq "#{subscriber_hbx_id}"
      expect(batch.employer_hbx_id).to eq "#{employer_hbx_id}"
      expect(batch.benefit_kind).to eq 'shop'
      expect(batch.aasm_state).to eq 'open'
    end

    it "should associate transaction with batch" do
      expect(channel).to receive(:ack).with(delivery_tag, false)
      subject.on_message(delivery_info, properties, body)

      expect(EnrollmentEvents::Batch.all.count).to eq 1
      batch = EnrollmentEvents::Batch.first

      expect(batch.transactions.count).to eq 1
      transaction = batch.transactions.first
      expect(transaction.batch_id).to eq batch.id
      expect(transaction.payload).to eq body
      expect(transaction.headers).to eq "#{headers}"
    end

    it "should broadcast batch created and transaction updated message" do
      expect(event_broadcaster).to receive(:broadcast).with({
        :routing_key => "info.application.glue.enrollment_event_handler.batch_created",
        :headers=> {
          :employer_hbx_id => "1",
          :subscriber_hbx_id => "1",
          :benefit_kind => "shop",
          :event_time=> "#{@time_now.to_i}",
          :return_status => "200",
          :submitted_timestamp=> @time_now }
        },
      body)
      expect(event_broadcaster).to receive(:broadcast).with({
        :routing_key => "info.application.glue.enrollment_event_handler.batch_transactions_updated",
        :headers=> {
          :employer_hbx_id => "1",
           :subscriber_hbx_id => "1",
           :benefit_kind => "shop",
           :event_time=> "#{@time_now.to_i}",
           :return_status => "200",
           :submitted_timestamp=> @time_now}
        },
      body)
      subject.on_message(delivery_info, properties, body)
    end

    it "should update existing batch with transaction" do
      expect(channel).to receive(:ack).with(delivery_tag, false)
      subject.on_message(delivery_info, properties, body)
      subject.on_message(delivery_info, properties, body)
      expect(EnrollmentEvents::Batch.all.count).to eq 1
      batch = EnrollmentEvents::Batch.first
      expect(batch.transactions.count).to eq 2
    end
  end

  context "given an IVL enrollment message" do
    let(:subscriber_hbx_id) { 1 }
    let(:delivery_tag) { double }
    let(:delivery_info) { double(delivery_tag: delivery_tag, routing_key: nil) }
    let(:headers) {double}
    let(:event_time) { Time.now }
    let(:properties) do
      double(
          headers: headers,
          timestamp: event_time
      )
    end
    let(:body) { <<-EVENTXML
      <enrollment_event xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='http://openhbx.org/api/terms/1.0'>
      <header>
        <hbx_id>29035</hbx_id>
        <submitted_timestamp>2016-11-08T17:44:49</submitted_timestamp>
      </header>
      <event>
        <body>
          <enrollment_event_body xmlns="http://openhbx.org/api/terms/1.0">
            <affected_members>
            </affected_members>
            <enrollment xmlns="http://openhbx.org/api/terms/1.0">
              <policy>
                <id>
                  <id>123</id>
                </id>
                <enrollees>
                  <enrollee>
                    <member>
                      <id><id>#{subscriber_hbx_id}</id></id>
                    </member>
                    <is_subscriber>true</is_subscriber>
                    <benefit>
                      <premium_amount>111.11</premium_amount>
                      <begin_date>#{Date.today.next_year.beginning_of_year.strftime("%Y%m%d")}</begin_date>
                    </benefit>
                  </enrollee>
                </enrollees>
                <enrollment>
                  <individual_market>
                    <assistance_effective_date>TOTALLY BOGUS</assistance_effective_date>
                    <applied_aptc_amount>100.00</applied_aptc_amount>
                  </individual_market>
                  <premium_total_amount>56.78</premium_total_amount>
                  <total_responsible_amount>123.45</total_responsible_amount>
                </enrollment>
              </policy>
            </enrollment>
            </enrollment_event_body>
        </body>
      </event>
    </enrollment_event>
    EVENTXML
    }

    before(:each) do
      allow(channel).to receive(:ack).with(delivery_tag, false)
      allow(Amqp::EventBroadcaster).to receive(:new).with(connection).and_return(event_broadcaster)
      @time_now = Time.now
      allow(Time).to receive(:now).and_return(@time_now)
      allow(event_broadcaster).to receive(:broadcast).with({
       :routing_key => "info.application.glue.enrollment_event_handler.batch_created",
       :headers=> {
         :employer_hbx_id => nil,
         :subscriber_hbx_id => "1",
         :benefit_kind => "individual",
         :event_time=> "#{@time_now.to_i}",
         :return_status => "200",
         :submitted_timestamp=> @time_now }
       }, body)
      allow(event_broadcaster).to receive(:broadcast).with({
        :routing_key => "info.application.glue.enrollment_event_handler.batch_transactions_updated",
        :headers=> {
          :employer_hbx_id => nil,
          :subscriber_hbx_id => "1",
          :benefit_kind => "individual",
          :event_time=> "#{@time_now.to_i}",
          :return_status => "200",
          :submitted_timestamp=> @time_now }
        }, body)
    end

    it "acknowledges the message" do
      expect(channel).to receive(:ack).with(delivery_tag, false)
      subject.on_message(delivery_info, properties, body)
    end

    it "should create enrollment batch with open status" do
      expect(EnrollmentEvents::Batch.all.count).to eq 0
      expect(channel).to receive(:ack).with(delivery_tag, false)
      subject.on_message(delivery_info, properties, body)

      expect(EnrollmentEvents::Batch.all.count).to eq 1
      batch = EnrollmentEvents::Batch.first
      expect(batch.subscriber_hbx_id).to eq "#{subscriber_hbx_id}"
      expect(batch.employer_hbx_id).to eq nil
      expect(batch.benefit_kind).to eq 'individual'
      expect(batch.aasm_state).to eq 'open'
    end

    it "should associate transaction with batch" do
      expect(channel).to receive(:ack).with(delivery_tag, false)
      subject.on_message(delivery_info, properties, body)

      expect(EnrollmentEvents::Batch.all.count).to eq 1
      batch = EnrollmentEvents::Batch.first

      expect(batch.transactions.count).to eq 1
      transaction = batch.transactions.first
      expect(transaction.batch_id).to eq batch.id
      expect(transaction.payload).to eq body
      expect(transaction.headers).to eq "#{headers}"
    end

    it "should update existing batch with transaction" do
      expect(channel).to receive(:ack).with(delivery_tag, false)
      subject.on_message(delivery_info, properties, body)
      subject.on_message(delivery_info, properties, body)
      expect(EnrollmentEvents::Batch.all.count).to eq 1
      batch = EnrollmentEvents::Batch.first
      expect(batch.transactions.count).to eq 2
    end
  end

  context "when processing enrollment_batch.cut message" do
    let(:employer_hbx_id) { 1 }
    let(:subscriber_hbx_id) { 1 }
    let(:delivery_tag) { double }
    let(:delivery_info) { double(delivery_tag: delivery_tag, routing_key: "") }
    let(:headers) {double}
    let(:event_time) { Time.now }
    let(:properties) do
      double(
        headers: headers,
        timestamp: event_time
      )
    end
    let(:body) { <<-EVENTXML
      <enrollment_event xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='http://openhbx.org/api/terms/1.0'>
      <header>
        <hbx_id>29035</hbx_id>
        <submitted_timestamp>2016-11-08T17:44:49</submitted_timestamp>
      </header>
      <event>
        <body>
          <enrollment_event_body xmlns="http://openhbx.org/api/terms/1.0">
            <affected_members>
            </affected_members>
            <enrollment xmlns="http://openhbx.org/api/terms/1.0">
              <policy>
                <id>
                  <id>123</id>
                </id>
                <enrollees>
                  <enrollee>
                    <member>
                      <id><id>#{subscriber_hbx_id}</id></id>
                    </member>
                    <is_subscriber>true</is_subscriber>
                    <benefit>
                      <premium_amount>111.11</premium_amount>
                      <begin_date>#{Date.today.next_year.beginning_of_year.strftime("%Y%m%d")}</begin_date>
                    </benefit>
                  </enrollee>
                </enrollees>
                <enrollment>
                  <individual_market>
                    <assistance_effective_date>TOTALLY BOGUS</assistance_effective_date>
                    <applied_aptc_amount>100.00</applied_aptc_amount>
                  </individual_market>
                  <premium_total_amount>56.78</premium_total_amount>
                  <total_responsible_amount>123.45</total_responsible_amount>
                </enrollment>
              </policy>
            </enrollment>
            </enrollment_event_body>
        </body>
      </event>
    </enrollment_event>
    EVENTXML
    }

    before(:each) do
      batch = EnrollmentEvents::Batch.create
      allow(channel).to receive(:ack).with(delivery_tag, false)
      allow(Amqp::EventBroadcaster).to receive(:new).with(connection).and_return(event_broadcaster)
      @time_now = Time.now
      allow(Time).to receive(:now).and_return(@time_now)
      allow(event_broadcaster).to receive(:broadcast).with({
        :routing_key => "info.application.glue.enrollment_event_handler.batch_created",
        :headers=> {
          :employer_hbx_id => nil,
          :subscriber_hbx_id => "1",
          :benefit_kind => "individual",
          :event_time=> "#{@time_now.to_i}",
          :return_status => "200",
          :submitted_timestamp=> @time_now
        }
      }, body)
      allow(event_broadcaster).to receive(:broadcast).with({
        :routing_key => "info.application.glue.enrollment_event_handler.batch_transactions_updated",
        :headers=> {
          :employer_hbx_id => nil,
          :subscriber_hbx_id => "1",
          :benefit_kind => "individual",
          :event_time=> "#{@time_now.to_i}",
          :return_status => "200",
          :submitted_timestamp=> @time_now
        }
      }, body)
      allow(event_broadcaster).to receive(:broadcast).with({
        :routing_key => "info.application.glue.enrollment_event_handler.batch_cut",
        :headers=> {
          :return_status => "200",
          :submitted_timestamp=> @time_now
        }
      }, "")
      allow(event_broadcaster).to receive(:broadcast).with({
        :routing_key => "info.application.glue.enrollment_event_handler.batch_processing",
        :headers=> {
          :batch_id => batch.id,
          :return_status => "200",
          :submitted_timestamp=> @time_now
        }
      }, "")
      allow(::Amqp::ConfirmedPublisher).to receive(:with_confirmed_channel).with(connection).and_yield(channel)
      allow(ExchangeInformation).to receive(:event_publish_exchange).and_return(event_exchange_name)
      allow(channel).to receive(:topic).with(event_exchange_name, {:durable => true}).and_return(default_exchange)
      allow(default_exchange).to receive(:publish).with(
        "",
        {
          :routing_key => "info.events.enrollment_batch.process",
          :headers => { batch_id: batch.id }
        }
      )
    end

    it "should update batch from open to pending state" do
      batch = EnrollmentEvents::Batch.all.first
      expect(batch.aasm_state).to eq "open"
      delivery_info = double(delivery_tag: delivery_tag, routing_key: "info.events.enrollment_batch.cut")
      subject.on_message(delivery_info, properties, body)
      batch.reload
      expect(batch.aasm_state).to eq "pending_transmission"
    end

    it "should publish batch process event" do
      batch = EnrollmentEvents::Batch.all.first
      expect(default_exchange).to receive(:publish).with(
        "",
        {
          :routing_key => "info.events.enrollment_batch.process",
          :headers => { batch_id: batch.id }
        }
      )
      delivery_info = double(delivery_tag: delivery_tag, routing_key: "info.events.enrollment_batch.cut")
      subject.on_message(delivery_info, properties, body)
    end
  end
end
