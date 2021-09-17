module ExternalEvents
  class BatchRecordResponder
    attr_reader :amqp_response_channel
    attr_reader :base_response_tag
    attr_reader :batch_id

    def initialize(br_tag, amqp_rc, batch_id)
      @batch_id = batch_id
      @base_response_tag = br_tag
      @amqp_response_channel = amqp_rc
    end

    def connection
      @amqp_response_channel.connection
    end

    def ack_message(message_tag)

    end

    def broadcast_ok_response(event_key, body = "", other_headers = {})
      broadcast_response("info", event_key, "200", body, other_headers)
    end

    def broadcast_response(level, event_key, response_code, body = "", other_headers = {})
      event_body = (body.respond_to?(:to_s) ? body.to_s : body.inspect)
      broadcast_event({
                          :routing_key => "#{level}.#{base_response_tag}.#{event_key}",
                          :headers => other_headers.merge({
                                                              :return_status => response_code.to_s,
                                                              :batch_id => batch_id
                                                          })
                      }, event_body)
    end

    protected

    def broadcast_event(props, payload)
      broadcaster = ::Amqp::EventBroadcaster.new(amqp_response_channel.connection)
      broadcaster.broadcast(props, payload)
    end

  end
end