require 'json'

module Amqp
  class Client
    attr_reader :channel, :queue

    def initialize(chan, q)
      @channel = chan
      @queue = q
      @argument_errors = []
      @bad_argument_queue = ExchangeInformation.invalid_argument_queue
      @processing_failed_queue = ExchangeInformation.processing_failure_queue
      @exit_after_work = false
    end

    def add_error(err)
      @argument_errors << err
    end

    def fail_with(err)
      $stderr.puts err.message
      $stderr.puts err.inspect
      $stderr.puts err.backtrace.join("\n")
    end
    
    def validate(delivery_info, properties, payload)
      # Override me
    end

    def passes_validation?(delivery_info, properties, payload)
      validate(delivery_info, properties, payload)
      !@argument_errors.any?
    end

    def publish_processing_failed(delivery_info, properties, payload, err)
      error_message = {
        :error => {
          :message => err.message,
          :inspected => err.inspect,
          :backtrace => err.backtrace.join("\n")
        },
        :original_payload => payload.to_s.encode('UTF-8', undef: :replace, replace: '')
      }
      @channel.default_exchange.publish(JSON.dump(error_message), error_properties(@processing_failed_queue, delivery_info, properties))
      channel.acknowledge(delivery_info.delivery_tag, false)
    end

    def publish_argument_errors(delivery_info, properties, payload)
      error_message = {
        :errors => @argument_errors,
        :original_payload => payload
      }
      @channel.default_exchange.publish(error_message.to_json, error_properties(@bad_argument_queue, delivery_info, properties))
      channel.acknowledge(delivery_info.delivery_tag, false)
    end

    def start_running
      @running = true
    end

    def try_to_stop
      exit(0) if !@running
      @exit_after_work = true
    end

    def stop_if_needed
      exit(0) if @exit_after_work
      @running = false
    end

    def subscribe(opts = {})
      @running = false
      trap('TERM') { try_to_stop }
      trap('INT') { exit -1 }
      @queue.subscribe(opts) do |delivery_info, properties, payload|
        start_running
        begin
          if passes_validation?(delivery_info, properties, payload)
            on_message(delivery_info, properties, payload)
          else
            publish_argument_errors(delivery_info, properties, payload)
          end
        rescue => e
          $stderr.puts "=== Processing Failure ==="
          fail_with(e)
          begin
            p_headers = properties.headers || {}
            existing_retry_count = p_headers["x-redelivery-count"].to_i
            if existing_retry_count > 5
              $stderr.puts "=== Redelivery Attempts Exceeded ==="
              $stderr.puts properties.to_hash.inspect
              $stderr.puts payload
              publish_processing_failed(delivery_info, properties, payload, e)
            else
              redeliver(channel, existing_retry_count, delivery_info, properties, payload)
            end
          rescue => e
            $stderr.puts "=== Redelivery Failure ==="
            fail_with(e)
            throw :terminate, e
          end
        end
        stop_if_needed
      end
    end

    def redeliver(a_channel, existing_retry_count, delivery_info, properties, payload)
      new_properties = redelivery_properties(existing_retry_count, delivery_info, properties)
      queue.publish(payload, new_properties)
      a_channel.acknowledge(delivery_info.delivery_tag, false)
    end

    def error_properties(error_routing_key, delivery_info, properties, exception = nil)
      new_properties = properties.to_hash.dup
      new_headers = new_properties[:headers] || {}
      new_headers[:previous_routing_key] = delivery_info.routing_key
      new_properties[:routing_key] = error_routing_key
      new_properties[:timestamp] = extract_timestamp(properties)
      if exception
        new_headers[:return_status] = exception.return_status
        new_headers[:error_message] = exception.message
      end

      new_properties
    end

    def redelivery_properties(existing_retry_count, delivery_info, properties)
      new_properties = properties.to_hash.dup
      new_headers = new_properties[:headers] || {}
      new_headers["x-redelivery-count"] = existing_retry_count + 1
      new_properties[:headers] = new_headers
      new_properties[:routing_key] = delivery_info.routing_key
      new_properties[:timestamp] = extract_timestamp(properties)
      new_properties
    end

    def extract_timestamp(properties)
      message_ts = properties.timestamp
      if message_ts.blank?
        Time.now.to_i
      else
        if message_ts.kind_of?(Time)
          message_ts.to_i
        end
      end
    end

    def connection
      channel.connection
    end

    def broadcast_event(props, payload)
      broadcaster = ::Amqp::EventBroadcaster.new(connection)
      broadcaster.broadcast(props, payload)
=begin
      publish_props = props.dup
      chan = connection.create_channel
      begin
        chan.confirm_select
        out_ex = chan.fanout(ExchangeInformation.event_publish_exchange, :durable => true)
        if !(props.has_key?("timestamp") || props.has_key?(:timestamp))
          publish_props["timestamp"] = Time.now.to_i
        end
        out_ex.publish(payload, publish_props)
        chan.wait_for_confirms
      ensure
        chan.close
      end
=end
    end

    def request(properties, payload, timeout = 15)
      req_chan = channel.connection
      Amqp::Requestor.default.request(properties, payload, timeout)
    end

    def with_response_exchange
      chan = connection.create_channel
      begin
        chan.confirm_select
        publish_exchange = chan.default_exchange
        yield publish_exchange
        chan.wait_for_confirms
      ensure
        chan.close
      end
    end
  end
end
