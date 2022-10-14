class Protocols::X12::TransactionSetHeader
  include Mongoid::Document
  include Mongoid::Timestamps

  include AASM

  field :st01, as: :ts_id, type: String
  field :st02, as: :ts_control_number, type: String
  field :st03, as: :ts_implementation_convention_reference, type: String

  field :transaction_kind, type: String
  field :aasm_state, type: String
  field :ack_nak_processed_at, type: Time

# FIX: this should reference self.transmission.isa08
  field :receiver_id, type: String
  index({receiver_id: 1})

  index({st02: 1})
  index({aasm_state: 1})

  scope :all_transmitted,   where({aasm_state: :transmitted})
  scope :all_retransmitted, where({aasm_state: :retransmitted})
  scope :all_acknowledged,  where({aasm_state: :acknowledged})
  scope :all_rejected,      where({aasm_state: :rejected})

  scope :all_initial_enrollments,    where({transaction_kind: "initial_enrollment"})
  scope :all_enrollment_maintenances,    where({transaction_kind: "maintenance"})
  scope :all_enrollment_effectuations,    where({transaction_kind: "effectuation"})
  scope :all_premium_payment_remittances,    where({transaction_kind: "remittance"})


  belongs_to :carrier, index: true
  belongs_to :transmission, counter_cache: true, index: true, :class_name => "Protocols::X12::Transmission"

  mount_uploader :body, EdiBody

  validates_presence_of :ts_id, :ts_control_number, :ts_implementation_convention_reference, :transaction_kind
  validates_inclusion_of :transaction_kind, in: ["initial_enrollment", "maintenance", "effectuation", "remittance", "reinstatement"]
 
  aasm do
    state :transmitted, initial: true
    state :retransmitted
    state :acknowledged
    state :rejected

    event :nack do
      transitions from: :transmitted, to: :rejected
    end

    event :retransmit do
      transitions from: :rejected, to: :retransmitted
    end

    event :ack do
      transitions from: :transmitted, to: :acknowledged
    end
  end

  def acknowledge!(the_date)
    self.ack_nak_processed_at = the_date
    self.aasm_state = 'acknowledged'
    self.save!
  end

  def retransmit!(the_date)
    self.ack_nak_processed_at = the_date
    self.aasm_state = 'retransmitted'
    self.save!
  end

  def reject!(the_date)
    self.ack_nak_processed_at = the_date
    self.aasm_state = 'rejected'
    self.save!
  end
end
