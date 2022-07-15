module Listeners
  class IndividualEventListener < Amqp::Client
    def self.queue_name
      ec = ExchangeInformation
      "#{ec.hbx_id}.#{ec.environment}.q.glue.individual_updated_listener"
    end

    def resource_event_broadcast(level, event_key, ind_id, r_code, body = "")
        event_body = (body.respond_to?(:to_s) ? body.to_s : body.inspect)
        submit_time = 
        broadcast_event({
          :routing_key => "#{level}.application.gluedb.individual_update_event_listener.#{event_key}",
          :headers => {
            :individual_id => ind_id,
            :return_status => r_code.to_s,
            :submitted_timestamp => Time.now
          }
        },event_body)
    end

    def resource_error_broadcast(event_key, ind_id, r_code, body = "")
      resource_event_broadcast("error", event_key, ind_id, r_code, body)
    end

    def process_retrieved_resource(delivery_info, individual_id, r_code, remote_resource)
      change_set = ::ChangeSets::IndividualChangeSet.new(remote_resource)
      begin
        if change_set.individual_exists?
          if change_set.any_changes?
            if change_set.dropping_subscriber_home_address?
              resource_event_broadcast("error", "subscriber_home_address_required", individual_id, "422", remote_resource)
              channel.ack(delivery_info.delivery_tag, false)
            elsif change_set.multiple_changes?
              if change_set.process_first_edi_change
                resource_event_broadcast("info", "individual_updated_partially", individual_id, r_code, remote_resource)
                channel.reject(delivery_info.delivery_tag, true)
              else
                resource_event_broadcast("error", "individual_updated", individual_id, "422", JSON.dump({:resource => remote_resource.to_s, :errors => change_set.full_error_messages }))
                channel.ack(delivery_info.delivery_tag, false)
              end
            else
              if change_set.process_first_edi_change
                resource_event_broadcast("info", "individual_updated", individual_id, r_code, remote_resource)
                channel.ack(delivery_info.delivery_tag, false)
              else
                resource_event_broadcast("error", "individual_updated", individual_id, "422", JSON.dump({:resource => remote_resource.to_s, :errors => change_set.full_error_messages }))
                channel.ack(delivery_info.delivery_tag, false)
              end
            end
          else
            resource_event_broadcast("info", "individual_updated", individual_id, "304", remote_resource)
            channel.ack(delivery_info.delivery_tag, false)
          end
        else
          if change_set.create_individual_resource
            resource_event_broadcast("info", "individual_created", individual_id, r_code, remote_resource)
            channel.ack(delivery_info.delivery_tag, false)
          else
            resource_event_broadcast("error", "individual_created", individual_id, "422", JSON.dump({:resource => remote_resource.to_s, :errors => change_set.full_error_messages }))
            channel.ack(delivery_info.delivery_tag, false)
          end
        end
      rescue BusinessProcesses::TransformationError => e
        resource_error_broadcast("edi_transformation_failure", individual_id, "500", {
          errors: e.message,
          input: e.input          
        }.to_json)
        channel.ack(delivery_info.delivery_tag, false)
      end
    end

    def on_message(delivery_info, properties, body)
      m_headers = (properties.headers || {}).to_hash.stringify_keys
      individual_id = m_headers["individual_id"].to_s
      r_code, resource_or_body = ::RemoteResources::IndividualResource.retrieve(self, individual_id)
      case r_code.to_s
      when "200"
        process_retrieved_resource(delivery_info, individual_id, r_code, resource_or_body)
      when "404"
        resource_error_broadcast("resource_not_found", individual_id, r_code)
        channel.ack(delivery_info.delivery_tag, false)
      when "503"
        resource_error_broadcast("resource_timeout", individual_id, r_code)
        channel.reject(delivery_info.delivery_tag, true)
      else
        resource_error_broadcast("unknown_error", individual_id, r_code, resource_or_body)
        channel.ack(delivery_info.delivery_tag, false)
      end
    end

    def self.bind(channel, queue)
      topic_exchange = channel.topic(ExchangeInformation.event_exchange, {durable: true})
      queue.bind(topic_exchange, {:routing_key => "info.events.individual.created"})
      queue.bind(topic_exchange, {:routing_key => "info.events.individual.updated"})
    end

    def self.run
      Process.setproctitle("%s - %s" % [self.name , $$])
      conn = AmqpConnectionProvider.start_connection
      chan = conn.create_channel
      chan.prefetch(1)
      q = chan.queue(self.queue_name, :durable => true)
      bind(chan, q)
      self.new(chan, q).subscribe(:block => true, :manual_ack => true, :ack => true)
      conn.close
    end
  end
end
