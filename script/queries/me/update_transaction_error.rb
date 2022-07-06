map = {
  "Etf loop has too many subscribers" => "A single transaction has multiple subscribers",
  "Etf loop has no valid plan" => "	Policy id and/or plan HIOS Id does not match",
  "Etf loop has an invalid broker" => "Broker Information is invalid",
  "Etf loop is missing coverage loops" => "One or more Coverage loops are missing",
  "Etf loop is missing PRE AMT 1" => "One or more Member Reporting Category loop is missing the PRE AMT 1 element"
}

Protocols::X12::TransactionSetEnrollment.where("error_list" => {"$exists" => true, "$not" => {"$size" => 0}}).each do |txrn|
  error = txrn.error_list.map {|e| map[e].present? ? map[e] : e }
  txrn.error_list = error
  txrn.save
end

Protocols::X12::TransactionSetEnrollment.where("error_list" => {"$exists" => true, "$not" => {"$size" => 0}}).each do |txrn|
  body = txrn.body.read
  result = body.sub("~REF*1L*", 'policy_id:')
  if result.match(/(?:policy_id:)([\d]+)/).present?
    ids = result.match(/(?:policy_id:)([\d]+)/)[1]
    if Policy.where(:hbx_enrollment_ids => ids).first
      txrn.policy_id = Policy.where(hbx_enrollment_ids:ids).first.id
      txrn.save
    end
  end
end