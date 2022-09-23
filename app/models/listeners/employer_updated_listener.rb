module Listeners
  class EmployerUpdatedListener < ::Amqp::Client
    VOCAB_NS = {:v => "http://openhbx.org/api/terms/1.0"}
    FailAction = Struct.new(:ack, :requeue, :event_name, :message)

    def on_message(delivery_info, properties, body, time_provider = Time)
      headers = (properties.headers || {})
      employer_id = headers.to_hash.stringify_keys['employer_id']

      sc = ShortCircuit.on(:fail) do |fail_action|
        log_event("error", fail_action.event_name, employer_id, fail_action.message, time_provider)
        if fail_action.ack
          channel.acknowledge(delivery_info.delivery_tag, false)
        else
          channel.nack(delivery_info.delivery_tag, false, fail_action.requeue)
        end
      end
      sc.and_then do |e_id|
        employers = Employer.by_hbx_id(e_id)
        if employers.any?
          employer_attributes = get_employer_properties(e_id, false)
          employer = employers.first
          if employer.update_attributes(employer_attributes)
            log_event("info", "employer_updated", e_id, "", time_provider)
          else
            error_payload = JSON.dump({
              :employer_attributes => employer_attributes,
              :errors => employer.errors.full_messages
            })
            throw :fail, FailAction.new(true, true, "invalid_employer_update", error_payload)
          end
        else
          employer_attributes = get_employer_properties(e_id, false)
          new_employer = Employer.new(employer_attributes)
          if new_employer.save
            log_event("info", "employer_created", e_id, "", time_provider)
          else
            error_payload = JSON.dump({
              :employer_attributes => employer_attributes,
              :errors => new_employer.errors.full_messages
            })
            throw :fail, FailAction.new(true, true, "invalid_employer_creation", error_payload)
          end
        end
        channel.acknowledge(delivery_info.delivery_tag, false)
      end
      sc.call(employer_id)
    end

    def get_employer_properties(employer_id, new_employer)
      xml_string = request_resource(employer_id)
      xml = Nokogiri::XML(xml_string)
      {
        :name => Maybe.new(xml.at_xpath("//v:organization/v:name", VOCAB_NS)).content.value,
        :dba => Maybe.new(xml.at_xpath("//v:organization/v:dba", VOCAB_NS)).content.value,
        :fein => Maybe.new(xml.at_xpath("//v:organization/v:fein", VOCAB_NS)).content.value,
        :hbx_id => Maybe.new(xml.at_xpath("//v:organization/v:id/v:id", VOCAB_NS)).content.value
      }
    end

    def request_resource(employer_id)
      di, rprops, rbody = request({
        :headers => {
          :employer_id => employer_id
        },
        :routing_key => "resource.employer"
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

    def log_event(level, event_name, employer_id, message, time_provider)
      e_ex_name = ExchangeInformation.event_publish_exchange
      chan = connection.create_channel
      e_ex = chan.fanout(e_ex_name, {:durable => true})
      e_ex.publish(message, {
        :routing_key => "#{level}.application.gluedb.employer_update_listener.#{event_name}",
        :timestamp => time_provider.now.to_i,
        :headers => {
          :employer_id => employer_id
        }
      })
      chan.close
    end

    def self.queue_name
      ec = ExchangeInformation
      "#{ec.hbx_id}.#{ec.environment}.q.glue.employer_updated_listener"
    end

    def self.run
      Process.setproctitle("%s - %s" % [self.name , $$])
      conn = AmqpConnectionProvider.start_connection
      chan = conn.create_channel
      chan.prefetch(1)
      q = chan.queue(self.queue_name, :durable => true)
      self.new(chan, q).subscribe(:block => true, :manual_ack => true, :ack => true)
      conn.close
    end
  end
end
