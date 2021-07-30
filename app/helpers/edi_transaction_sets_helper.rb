module EdiTransactionSetsHelper

  def transaction_error_sender_name
    sender = t.transmission.sender
    return sender.name if sender
    "No sender for ISA CODE #{t.transmission.ic_sender_id}"
  end
end
