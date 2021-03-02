module EnrollmentEvents
  class Transaction
    include Mongoid::Document
    include Mongoid::Timestamps
    extend Mongorder

    field :batch_id, type: Time
    field :payload, type: String
    field :headers, type: String
    field :event_time, type: Time

    belongs_to :batch, index: true

    index({batch_id: 1, payload: 1, headers: 1,  event_time: 1})

  end
end

