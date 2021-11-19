module EnrollmentEvents
  class Transaction
    include Mongoid::Document
    include Mongoid::Timestamps
    extend Mongorder

    field :payload, type: String
    field :headers, type: Hash
    field :event_time, type: Time

    belongs_to :batch, index: true

    index({batch_id: 1, headers: 1,  event_time: 1})

  end
end
