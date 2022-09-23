module Listeners
  class BrokerUpdatedListener < ::Amqp::Client
    VOCAB_NS = {:v => "http://openhbx.org/api/terms/1.0"}
    FailAction = Struct.new(:ack, :requeue, :event_name, :message)

    def on_message(delivery_info, properties, body, time_provider = Time)
      headers = (properties.headers || {})
      broker_id = headers.to_hash.stringify_keys['broker_id']

      sc = ShortCircuit.on(:fail) do |fail_action|
        log_event("error", fail_action.event_name, broker_id, fail_action.message, time_provider)
        if fail_action.ack
          channel.acknowledge(delivery_info.delivery_tag, false)
        else
          channel.nack(delivery_info.delivery_tag, false, fail_action.requeue)
        end
      end
      sc.and_then do |b_id|
        brokers = Broker.by_npn(b_id)
        if brokers.any?
          broker_attributes = get_broker_properties(b_id, false)
          broker = brokers.first
          if broker.update_attributes(broker_attributes)
            log_event("info", "broker_updated", b_id, "", time_provider)
          else
            error_payload = JSON.dump({
              :broker_attributes => broker_attributes,
              :errors => broker.errors.full_messages
            })
            throw :fail, FailAction.new(true, true, "invalid_broker_update", error_payload)
          end
        else
          broker_attributes = get_broker_properties(b_id, false)
          new_broker = Broker.new(broker_attributes)
          if new_broker.save
            log_event("info", "broker_created", b_id, "", time_provider)
          else
            error_payload = JSON.dump({
              :broker_attributes => broker_attributes,
              :errors => new_broker.errors.full_messages
            })
            throw :fail, FailAction.new(true, true, "invalid_broker_creation", error_payload)
          end
        end
        channel.acknowledge(delivery_info.delivery_tag, false)
      end
      sc.call(broker_id)
    end

    def get_broker_properties(broker_id, new_broker)
      xml_string = request_resource(broker_id)
      xml = Nokogiri::XML(xml_string)
      {
        :name_first => Maybe.new(xml.at_xpath("//v:person/v:person_name/v:person_given_name", VOCAB_NS)).content.value,
        :name_last => Maybe.new(xml.at_xpath("//v:person/v:person_name/v:person_surname", VOCAB_NS)).content.value,
        :name_middle => Maybe.new(xml.at_xpath("//v:person/v:person_name/v:person_middle_name", VOCAB_NS)).content.value,
        :name_pfx => Maybe.new(xml.at_xpath("//v:person/v:person_name/v:person_name_prefix_text", VOCAB_NS)).content.value,
        :name_sfx => Maybe.new(xml.at_xpath("//v:person/v:person_name/v:person_name_suffix_text", VOCAB_NS)).content.value,
        :npn => Maybe.new(xml.at_xpath("//v:broker_role/v:npn", VOCAB_NS)).content.value,
        :b_type => "broker"
      }
    end

    def request_resource(broker_id)
      di, rprops, rbody = request({
        :headers => {
          :broker_id => broker_id
        },
        :routing_key => "resource.broker"
      },"",10)
      if rprops.nil?
        throw :fail, FailAction.new(false, true, "resource_lookup_timeout", "")
      end
      r_headers = rprops.headers || {}
      r_status = r_headers.stringify_keys["return_status"]
      if "404" == r_status.to_s
        throw :fail, FailAction.new(true, true, "non_existant_resource", "")
      end
      rbody
    end

    def log_event(level, event_name, broker_id, message, time_provider)
      e_ex_name = ExchangeInformation.event_publish_exchange
      chan = connection.create_channel
      e_ex = chan.fanout(e_ex_name, {:durable => true})
      e_ex.publish(message, {
        :routing_key => "#{level}.application.gluedb.broker_update_listener.#{event_name}",
        :timestamp => time_provider.now.to_i,
        :headers => {
          :broker_id => broker_id
        }
      })
      chan.close
    end

    def self.queue_name
      ec = ExchangeInformation
      "#{ec.hbx_id}.#{ec.environment}.q.glue.broker_updated_listener"
    end

    def self.run
      conn = AmqpConnectionProvider.start_connection
      chan = conn.create_channel
      chan.prefetch(1)
      q = chan.queue(self.queue_name, :durable => true)
      self.new(chan, q).subscribe(:block => true, :manual_ack => true, :ack => true)
      conn.close
    end
  end
end
