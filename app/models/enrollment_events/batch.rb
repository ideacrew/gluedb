module EnrollmentEvents
  class Batch
    include Mongoid::Document
    include Mongoid::Timestamps
    extend Mongorder
    include AASM

    field :subscriber_hbx_id, type: String
    field :employer_hbx_id, type: String
    field :benefit_kind, type: String
    field :aasm_state, type: String

    default_scope ->{ where(aasm_state: 'open') }

    has_many :transactions,
             class_name: "EnrollmentEvents::Transaction",
             order: { submitted_at: :desc }

    index({subscriber_hbx_id: 1, employer_hbx_id: 1, benefit_kind: 1, aasm_state: 1})

    aasm do
      state :open, initial: true
      state :pending_transmission
      state :closed
      state :error

      event :process do
        transitions from: [:open,:error], to: :pending_transmission
      end

      event :transmit do
        transitions from: :pending_transmission, to: :closed
      end

      event :exception do
        transitions from: :pending_transmission, to: :error
      end
    end

    def self.new_batch?(parsed_event)
      self.where({
        subscriber_hbx_id: parsed_event.subscriber_id,
        employer_hbx_id: parsed_event.employer_hbx_id,
        benefit_kind: parsed_event.determine_market(parsed_event.enrollment_event_xml)
      }).any?
    end

    def self.find_batch(parsed_event)
      self.where({
                     subscriber_hbx_id: parsed_event.subscriber_id,
                     employer_hbx_id: parsed_event.employer_hbx_id,
                     benefit_kind: parsed_event.determine_market(parsed_event.enrollment_event_xml)
                 }).first
    end

    def self.create_batch_and_yield(parsed_event)
      new_batch = create_batch(parsed_event)
      yield new_batch
    end

    def self.create_batch(parsed_event)
      self.create!({
        subscriber_hbx_id: parsed_event.subscriber_id,
        employer_hbx_id: parsed_event.employer_hbx_id,
        benefit_kind: parsed_event.determine_market(parsed_event.enrollment_event_xml)
      })
    end

    def self.create_batch_transactions_and_yield(parsed_event, new_payload, m_headers, event_time)
      transaction = create_transaction(find_batch(parsed_event), new_payload, m_headers, event_time)
      yield transaction
    end

    def self.create_transaction(batch, new_payload, m_headers, event_time)
      batch.transactions.create!({
        payload: new_payload,
        headers: m_headers,
        event_time: event_time
      })
    end
  end
end


