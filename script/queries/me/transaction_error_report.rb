require 'csv'

puts "Started At #{Time.now}"

start_date = (Time.now - 1.week).beginning_of_day
end_date = (Time.now - 1.day).end_of_day
formatted_start_date = start_date.getlocal.strftime('%m-%d-%Y')
formatted_end_date = end_date.getlocal.strftime('%m-%d-%Y')
count = 0

transaction_errors = Protocols::X12::TransactionSetEnrollment.where("error_list" => {"$exists" => true, "$not" => {"$size" => 0}},
                                                                    :created_at => {"$gte" => start_date, "$lte" => end_date}).no_timeout

TradingPartner.all.each do |td|
	instance_variable_set("@#{td.name.downcase.gsub(" ", "_") + "_error"}", [])
end

total_transactions = transaction_errors.count.to_d
cat_count = 0
transaction_errors.each do |error|
	cat_count += 1
  puts "#{Time.now} - #{cat_count}" if (cat_count % 100) == 0
  transmission = error.transmission
	carrier_name = transmission.sender.try(:name)
	if carrier_name.present?
    errors = "@#{carrier_name.downcase.gsub(" ", "_") + "_error"}"
   instance_variable_get(errors).push(error)
	end
end

def parse_edi_for_hbx_id(body)
	transaction_array = body.split(/~/)
	if transaction_array.size == 1
		transaction_array = body.split(/,/)
	end
	correct_segment = transaction_array.select{|segment| segment.match(/REF\S0F/)}
	if correct_segment.count != 0
		return correct_segment.first.gsub("REF*0F*","")
	else
		return "Not Found in EDI"
	end
end

def parse_edi_for_eg_id(body)
	transaction_array = body.split(/~/)
	if transaction_array.size == 1
		transaction_array = body.split(/,/)
	end
	correct_segment = transaction_array.select{|segment| segment.match(/REF\S1L/)}
	if correct_segment.count != 0
		return correct_segment.first.gsub("REF*1L*","")
	else
		return "Not Found in EDI"
	end
end

def find_subscriber(policy)
	subscriber = policy.subscriber
	if subscriber == nil
		subscriber = policy.enrollees.select {|enrollee| enrollee.rel_code == "self"}.first
	end
	return subscriber
end

Dir.mkdir("error_reports") unless File.exists?("error_reports")
TradingPartner.all.each do |td|
  report_file = "transaction_errors_#{td.name.gsub(" ", "_")}_#{formatted_start_date}-#{formatted_end_date}.csv"
	filename = "#{Rails.root}/error_reports/#{report_file}"
	errors = "@#{td.name.downcase.gsub(" ", "_") + "_error"}"
  carrier_errors = instance_variable_get(errors)
  CSV.open(filename,"w") do |csv|
		csv << ["Carrier","Transaction Kind", "Filename", "ISA13", "Transaction ID", "BGN02","Policy ID","Subscriber HBX ID", "Submitted At Date",
            "Submitted At Time", "Market", "Error Description"]
		carrier_errors.each do |transaction_error|
			count += 1
			if count % 1000 == 0
				puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
			end
			begin
				transaction_error.error_list.uniq.each do |error|
          next if error.to_s == "inbound reinstatements are blocked for legacy imports"
					if transaction_error.policy_id != nil
						filename = transaction_error.body.to_s
						carrier_name = td.name
						transmission = transaction_error.transmission
						transaction_kind = transaction_error.transaction_kind
						error_description = error
						bgn02 = transaction_error.bgn02
						policy = transaction_error.policy
						eg_id = policy.eg_id
						subscriber = find_subscriber(policy)
						subscriber_hbx_id = subscriber.try(:m_id)
						submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
						submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
						market = transmission.gs02
						isa13 = transmission.isa13
						txrn_id = transaction_error.st02
						csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), isa13, txrn_id, bgn02, eg_id, subscriber_hbx_id,
										submitted_at_date,submitted_at_time, market,
										error_description]
					elsif transaction_error.policy_id == nil
						filename = transaction_error.body.to_s
						carrier_name = td.name
						transmission = transaction_error.transmission
						transaction_kind = transaction_error.transaction_kind
						error_description = error
						bgn02 = transaction_error.bgn02
						edi_body = transaction_error.body.read
						eg_id = parse_edi_for_eg_id(edi_body)
						subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
						submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
						submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
						market = transmission.gs02
						isa13 = transmission.isa13
						txrn_id = transaction_error.st02
						csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), isa13, txrn_id, bgn02, eg_id, subscriber_hbx_id,
										submitted_at_date,submitted_at_time, market,
										error_description]
					end
        end
			end
		end
	end
end