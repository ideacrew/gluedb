module Listeners
  class EnrollmentEventBatchHandler < Amqp::Client

    BatchHandler = "info.events.enrollment_batch.handler"
    BatchCut = "info.events.enrollment_batch.cut"
    BatchProcess = "info.events.enrollment_batch.process"

    def self.queue_name
      ec = ExchangeInformation
      "#{ec.hbx_id}.#{ec.environment}.q.glue.enrollment_event_batch_handler"
    end

    def resource_event_broadcast(level, event_key, r_code, body = "", other_headers = {})
      event_body = (body.respond_to?(:to_s) ? body.to_s : body.inspect)
      broadcast_event({
        :routing_key => "#{level}.application.glue.enrollment_event_handler.#{event_key}",
        :headers => other_headers.merge({
          :return_status => r_code.to_s,
          :submitted_timestamp => Time.now
        })
      }, event_body)
    end

    def resource_error_broadcast(event_key, r_code, body = "", other_headers = {})
      resource_event_broadcast("error", event_key, r_code, body, other_headers)
    end

    def create_enrollment_batch(delivery_info, parsed_event, body, event_time)
      EnrollmentEvents::Batch.create_batch_and_yield(parsed_event) do |new_batch|
        resource_event_broadcast("info", "batch_created", "200", body, {
                                           :employer_hbx_id => new_batch.employer_hbx_id,
                                           :subscriber_hbx_id => new_batch.subscriber_hbx_id,
                                           :benefit_kind => new_batch.benefit_kind,
                                           :batch_id => Rails.env.test? ? "" : new_batch.id.to_s, # TODO: hack for spec.
                                           :event_time => event_time.to_i.to_s
                                       })
      end
      channel.ack(delivery_info.delivery_tag, false)
    end

    def create_batch_transaction(delivery_info, parsed_event, body, m_headers, event_time)
      EnrollmentEvents::Batch.create_batch_transaction_and_yield(parsed_event, body, m_headers, event_time) do |transaction|
        resource_event_broadcast("info", "batch_transactions_updated", "200", transaction.payload, {
                                           :employer_hbx_id => transaction.batch.employer_hbx_id,
                                           :subscriber_hbx_id => transaction.batch.subscriber_hbx_id,
                                           :benefit_kind => transaction.batch.benefit_kind,
                                           :batch_id => Rails.env.test? ? "" : transaction.batch_id.to_s, # TODO: hack for spec.
                                           :event_time => event_time.to_i.to_s
                                       })
      end
      channel.ack(delivery_info.delivery_tag, false)
    end

    def process_enrollment_batch
      if EnrollmentEvents::Batch.where(aasm_state: 'open').any?
        EnrollmentEvents::Batch.where(aasm_state: 'open').each do |batch|
           if batch.may_process?
             batch.process!
             Amqp::ConfirmedPublisher.with_confirmed_channel(connection) do |chan|
               ex = chan.topic(ExchangeInformation.event_exchange, {:durable => true})
               ex.publish(
                 "",
                 { routing_key: BatchProcess,
                   headers: { batch_id: batch.id.to_s }
                 }
               )
             end
             resource_event_broadcast("info", "batch_processing", "200", "", { batch_id: batch.id.to_s })
           end
        end
      end
    end

    def on_message(delivery_info, properties, body)
      m_headers = properties.headers || {}
      routing_key = delivery_info.routing_key
      event_time = extract_timestamp(properties)
      parsed_event = ExternalEvents::EnrollmentEventNotification.new(nil, delivery_info, event_time, body, m_headers)
      if routing_key == BatchCut
        resource_event_broadcast("info", "batch_cut", "200")
        process_enrollment_batch
        channel.ack(delivery_info.delivery_tag, false)
      else
        begin
          unless EnrollmentEvents::Batch.new_batch?(parsed_event)
            create_enrollment_batch(delivery_info,parsed_event, body, event_time)
            create_batch_transaction(delivery_info, parsed_event, body, m_headers, event_time)
          else
            create_batch_transaction(delivery_info, parsed_event, body, m_headers, event_time)
          end
        rescue => e
          resource_error_broadcast("unknown_error", "500", {:event => body, error: e.class.name, message: e.message , backtrace: e.backtrace.join("\n")}.to_json, m_headers)
          channel.ack(delivery_info.delivery_tag, false)
        end
      end
    end

    def self.create_queues(chan)
      ec = ExchangeInformation
      event_topic_exchange_name = "#{ec.hbx_id}.#{ec.environment}.e.topic.events"
      event_ex = chan.topic(event_topic_exchange_name, { :durable => true })
      q = chan.queue(
        self.queue_name,
        {
          :durable => true,
          :arguments => {
                "x-dead-letter-exchange" => (self.queue_name + "-retry")
          }
        }
      )
      q.bind(event_ex, {:routing_key => "info.events.enrollment_batch.cut"})
      retry_q = chan.queue(
        (self.queue_name + "-retry"),
        {
          :durable => true,
          :arguments => {
            "x-dead-letter-exchange" => (self.queue_name + "-requeue"),
            "x-message-ttl" => 1000
          }
        }
      )
      retry_exchange = chan.fanout(
          (self.queue_name + "-retry")
      )
      requeue_exchange = chan.fanout(
          (self.queue_name + "-requeue")
      )
      retry_q.bind(retry_exchange, {:routing_key => ""})
      q.bind(requeue_exchange, {:routing_key => ""})
      q
    end

    def self.run
      conn = AmqpConnectionProvider.start_connection
      chan = conn.create_channel
      q = create_queues(chan)
      chan.prefetch(1)
      self.new(chan, q).subscribe(:block => true, :manual_ack => true, :ack => true)
      conn.close
    end
  end
end
