module Listeners
  class EnrollmentEventBatchProcessor < Amqp::Client
    def self.queue_name
      ec = ExchangeInformation
      "#{ec.hbx_id}.#{ec.environment}.q.glue.enrollment_event_batch_processor"
    end

    def resource_event_broadcast(level, event_key, r_code, body = "", other_headers = {})
      event_body = (body.respond_to?(:to_s) ? body.to_s : body.inspect)
      broadcast_event({
        :routing_key => "#{level}.application.glue.enrollment_event_batch_processor.#{event_key}",
        :headers => other_headers.merge({
          :return_status => r_code.to_s,
          :submitted_timestamp => Time.now})
        }, event_body)
    end

    def resource_error_broadcast(event_key, r_code, body = "", other_headers = {})
      resource_event_broadcast("error", event_key, r_code, body, other_headers)
    end

    def on_message(delivery_info, properties, body)
      m_headers = properties.headers || {}
      responder = ::ExternalEvents::BatchRecordResponder.new(
        "application.gluedb.enrollment_event_batch_processor",
        channel, m_headers[:batch_id]
      )
      begin
        batch = EnrollmentEvents::Batch.where(id: properties.headers[:batch_id], aasm_state: "pending_transmission", ).first
        if batch.present?
          events = []
          batch.transactions.each do |transaction|
            event_message = ExternalEvents::EnrollmentEventNotification.new(
              responder,
              "",
              transaction.event_time,
              transaction.payload,
              transaction.headers
            )
            events << event_message
          end
          EnrollmentEventProcessingClient.new.call(events)
          channel.ack(delivery_info.delivery_tag, false)
          batch.transmit! if batch.may_transmit?
          resource_event_broadcast("info", "batch_processed", "200", body, m_headers)
        else
          resource_event_broadcast("info", "batch_not_found", "404", body, m_headers)
        end
        channel.ack(delivery_info.delivery_tag, false)
      rescue => error
        batch.exception! if batch.present?
        resource_error_broadcast("exception", "500", error.backtrace, m_headers)
        channel.ack(delivery_info.delivery_tag, false)
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
      q.bind(event_ex, {:routing_key => "info.events.enrollment_batch.process"})
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
