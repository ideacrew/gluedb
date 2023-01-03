module Listeners
  class EnrollmentBrokerUpdatedListener < Amqp::RetryClient
    def self.queue_name
      ec = ExchangeInformation
      "#{ec.hbx_id}.#{ec.environment}.q.glue.enrollment_broker_updated_listener"
    end

    def resource_event_broadcast(level, event_key, r_code, body = "", other_headers = {})
      event_body = (body.respond_to?(:to_s) ? body.to_s : body.inspect)
      broadcast_event({
                        :routing_key => "#{level}.application.glue.enrollment_broker_updated_listener.#{event_key}",
                        :headers => other_headers.merge({
                                                          :return_status => r_code.to_s,
                                                          :submitted_timestamp => Time.now})
                      }, event_body)
    end

    def resource_error_broadcast(event_key, r_code, body = "", other_headers = {})
      resource_event_broadcast("error", event_key, r_code, body, other_headers)
    end

    def on_message(delivery_info, properties, body)
      m_headers = (properties.headers || {}).to_hash.stringify_keys
      hbx_enrollment_id = m_headers["hbx_enrollment_id"].to_s
      npn = m_headers["new_broker_npn"].to_s
      policy = Policy.where(hbx_enrollment_ids: hbx_enrollment_id).first
      broker_id = nil
      unless npn.blank?
        broker_id = Broker.find_by_npn(npn).try(:id)
      end
      begin
        if broker_id.nil? && !npn.blank?
          resource_event_broadcast("error", "broker_not_found", "404", body, properties.headers)
        elsif policy.present? && policy.terminated?
          resource_event_broadcast("info", "broker_policy_terminated", "404", body, properties.headers)
        elsif policy.present? && !policy.terminated?
          update_broker_on_policy(broker_id, policy)
          resource_event_broadcast("info", "broker_policy_processed", "200", body, properties.headers)
        else
          resource_event_broadcast("error", "policy_not_found", "404", body, properties.headers)
        end
        channel.ack(delivery_info.delivery_tag, false)
      rescue => error
        resource_error_broadcast("exception", "500", error.backtrace, properties.headers)
        channel.reject(delivery_info.delivery_tag, false)
      end
    end

    def update_broker_on_policy(broker_id, policy)
      if policy.broker_id != broker_id
        policy.broker_id = broker_id
        policy.save!
        publish_to_edi(policy)
      end
    end

    def publish_to_edi(policy)
      member = policy.subscriber.person.authority_member
      af = ::BusinessProcesses::AffectedMember.new({
        :policy => policy
      }.merge({"member_id" => member.hbx_member_id, "gender" => member.gender}))
      ict = ChangeSets::IdentityChangeTransmitter.new(af, policy, "urn:openhbx:terms:v1:enrollment#change_broker")
      ict.publish
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
      q.bind(event_ex, {:routing_key => "info.events.family.broker_updates"})
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
