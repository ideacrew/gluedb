::Amqp::EventBroadcaster.with_broadcaster do |b|
  b.broadcast(
      { :headers => {},
        :routing_key => "info.events.enrollment_batch.cut"
      },
      ""
  )
end