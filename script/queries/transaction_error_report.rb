require 'csv'

puts "Started At #{Time.now}"

start_date = (Time.now - 1.week).beginning_of_day

end_date = (Time.now - 1.day).end_of_day

transaction_errors = Protocols::X12::TransactionSetEnrollment.where("error_list" => {"$exists" => true, "$not" => {"$size" => 0}},
																	:created_at => {"$gte" => start_date, "$lte" => end_date}).no_timeout

formatted_start_date = start_date.getlocal.strftime('%m-%d-%Y')
formatted_end_date = end_date.getlocal.strftime('%m-%d-%Y')

db = Mongoid::Sessions.default
carrier_collection = db[:carriers]

def find_subscriber(policy)
	subscriber = policy.subscriber
	if subscriber == nil
		subscriber = policy.enrollees.select {|enrollee| enrollee.rel_code == "self"}.first
	end
	return subscriber
end

count = 0

def find_carrier_name_by_filename(filename)
	if /GHMSI/.match(filename) != nil
		return "CareFirst"
	elsif /AHI/.match(filename) != nil
		return "Aetna"
	elsif /KFMASI/.match(filename) != nil
		return "Kaiser Permanente"
	elsif /UHIC/.match(filename) != nil
		return "United"
	elsif /BLHI/.match(filename) != nil
		return "BestLife"
	elsif /DCHBX/.match(filename) != nil
		return "DC HealthLink"
	elsif /DDPA/.match(filename) != nil
		return "Delta Dental"
	elsif /DTGA/.match(filename) != nil
		return "Dentegra"
	elsif /DMND/.match(filename) != nil
		return "Dominion"
	elsif /GARD/.match(filename) != nil
		return "Guardian"
	elsif /META/.match(filename) != nil
		return "MetLife"
	end
end

carefirst_ivl_errors = []
carefirst_shp_errors = []
aetna_ivl_errors = []
aetna_shp_errors = []
kaiser_ivl_errors = []
kaiser_shp_errors = []
united_ivl_errors = []
united_shp_errors = []
bestlife_ivl_errors = []
bestlife_shp_errors = []
dchl_ivl_errors = []
dchl_shp_errors = []
dd_ivl_errors = []
dd_shp_errors = []
dentegra_ivl_errors = []
dentegra_shp_errors = []
dominion_ivl_errors = []
dominion_shp_errors = []
guardian_ivl_errors = []
guardian_shp_errors = []
metlife_ivl_errors = []
metlife_shp_errors = []
uncat_ivl_errors = []
uncat_shp_errors = []

total_transactions = transaction_errors.count.to_d

cat_count = 0

transaction_errors.each do |error|
	cat_count += 1
	if cat_count % 100 == 0
		puts "#{Time.now} - #{cat_count}"
	end
	transmission = error.transmission
	market = transmission.gs02
	carrier_name = transmission.sender.try(:name)
	if market == "IND"
		if carrier_name == "CareFirst"
			carefirst_ivl_errors.push(error)
		elsif carrier_name == "Aetna"
			aetna_ivl_errors.push(error)
		elsif ["Kaiser", "Kaiser Permanente"].include?(carrier_name)
			kaiser_ivl_errors.push(error)
		elsif carrier_name == "United Health Care"
			united_ivl_errors.push(error)
		elsif carrier_name == "BestLife"
			bestlife_ivl_errors.push(error)
		elsif carrier_name == "DC HealthLink"
			dchl_ivl_errors.push(error)
		elsif carrier_name == "Delta Dental"
			dd_ivl_errors.push(error)
		elsif carrier_name == "Dentegra"
			dentegra_ivl_errors.push(error)
		elsif carrier_name == "Dominion"
			dominion_ivl_errors.push(error)
		elsif carrier_name == "Guardian"
			guardian_ivl_errors.push(error)
		elsif carrier_name == "MetLife"
			metlife_ivl_errors.push(error)
		else
			uncat_ivl_errors.push(error)
		end
	elsif market == "SHP"
		if carrier_name == "CareFirst"
			carefirst_shp_errors.push(error)
		elsif carrier_name == "Aetna"
			aetna_shp_errors.push(error)
		elsif ["Kaiser", "Kaiser Permanente"].include?(carrier_name)
			kaiser_shp_errors.push(error)
		elsif carrier_name == "United Health Care"
			united_shp_errors.push(error)
		elsif carrier_name == "BestLife"
			bestlife_shp_errors.push(error)
		elsif carrier_name == "DC HealthLink"
			dchl_shp_errors.push(error)
		elsif carrier_name == "Delta Dental"
			dd_shp_errors.push(error)
		elsif carrier_name == "Dentegra"
			dentegra_shp_errors.push(error)
		elsif carrier_name == "Dominion"
			dominion_shp_errors.push(error)
		elsif carrier_name == "Guardian"
			guardian_shp_errors.push(error)
		elsif carrier_name == "MetLife"
			metlife_shp_errors.push(error)
		else
			uncat_shp_errors.push(error)
		end
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

timestamp = Time.now.strftime('%Y%m%d%H%M')

CSV.open("transaction_errors_ivl_ghmsi_#{formatted_start_date}-#{formatted_end_date}.csv","w") do |csv|
	csv << ["Carrier","Transaction Kind", "Filename","BGN02","Policy ID","Subscriber HBX ID",
			"Submitted At Date", "Submitted At Time", "Ack/Nack Date", "Ack/Nack Time", "Market", "isa13",
			"Error Description"]
	carefirst_ivl_errors.each do |transaction_error|
		count += 1
		if count % 1000 == 0
			puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
		end
		begin
			if transaction_error.policy_id != nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				policy = transaction_error.policy
				eg_id = policy.eg_id
				subscriber = find_subscriber(policy)
				subscriber_hbx_id = subscriber.try(:m_id)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
						error_description]
			elsif transaction_error.policy_id == nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				edi_body = transaction_error.body.read
				eg_id = parse_edi_for_eg_id(edi_body)
				subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
				 		error_description]
			end
		rescue Exception=>e
			puts e.inspect
		end
	end
end

CSV.open("transaction_errors_ivl_ahi_#{formatted_start_date}-#{formatted_end_date}.csv","w") do |csv|
	csv << ["Carrier","Transaction Kind", "Filename","BGN02","Policy ID","Subscriber HBX ID",
			"Submitted At Date", "Submitted At Time", "Ack/Nack Date", "Ack/Nack Time", "Market", "isa13",
			"Error Description"]
	aetna_ivl_errors.each do |transaction_error|
		count += 1
		if count % 1000 == 0
			puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
		end
		begin
			if transaction_error.policy_id != nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				policy = transaction_error.policy
				eg_id = policy.eg_id
				subscriber = find_subscriber(policy)
				subscriber_hbx_id = subscriber.try(:m_id)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
						error_description]
			elsif transaction_error.policy_id == nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				edi_body = transaction_error.body.read
				eg_id = parse_edi_for_eg_id(edi_body)
				subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
				 		error_description]
			end
		rescue Exception=>e
			puts e.inspect
		end
	end
end

CSV.open("transaction_errors_ivl_kfmasi_#{formatted_start_date}-#{formatted_end_date}.csv","w") do |csv|
	csv << ["Carrier","Transaction Kind", "Filename","BGN02","Policy ID","Subscriber HBX ID",
			"Submitted At Date", "Submitted At Time", "Ack/Nack Date", "Ack/Nack Time", "Market", "isa13",
			"Error Description"]
	kaiser_ivl_errors.each do |transaction_error|
		count += 1
		if count % 1000 == 0
			puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
		end
		begin
			if transaction_error.policy_id != nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				policy = transaction_error.policy
				eg_id = policy.eg_id
				subscriber = find_subscriber(policy)
				subscriber_hbx_id = subscriber.try(:m_id)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
						error_description]
			elsif transaction_error.policy_id == nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				edi_body = transaction_error.body.read
				eg_id = parse_edi_for_eg_id(edi_body)
				subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
				 		error_description]
			end
		rescue Exception=>e
			puts e.inspect
		end
	end
end

CSV.open("transaction_errors_ivl_uhic_#{formatted_start_date}-#{formatted_end_date}.csv","w") do |csv|
	csv << ["Carrier","Transaction Kind", "Filename","BGN02","Policy ID","Subscriber HBX ID",
			"Submitted At Date", "Submitted At Time", "Ack/Nack Date", "Ack/Nack Time", "Market", "isa13",
			"Error Description"]
	united_ivl_errors.each do |transaction_error|
		count += 1
		if count % 1000 == 0
			puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
		end
		begin
			if transaction_error.policy_id != nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				policy = transaction_error.policy
				eg_id = policy.eg_id
				subscriber = find_subscriber(policy)
				subscriber_hbx_id = subscriber.try(:m_id)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
						error_description]
			elsif transaction_error.policy_id == nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				edi_body = transaction_error.body.read
				eg_id = parse_edi_for_eg_id(edi_body)
				subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
				 		error_description]
			end
		rescue Exception=>e
			puts e.inspect
		end
	end
end

CSV.open("transaction_errors_ivl_blhi_#{formatted_start_date}-#{formatted_end_date}.csv","w") do |csv|
	csv << ["Carrier","Transaction Kind", "Filename","BGN02","Policy ID","Subscriber HBX ID",
			"Submitted At Date", "Submitted At Time", "Ack/Nack Date", "Ack/Nack Time", "Market", "isa13",
			"Error Description"]
	bestlife_ivl_errors.each do |transaction_error|
		count += 1
		if count % 1000 == 0
			puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
		end
		begin
			if transaction_error.policy_id != nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				policy = transaction_error.policy
				eg_id = policy.eg_id
				subscriber = find_subscriber(policy)
				subscriber_hbx_id = subscriber.try(:m_id)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
						error_description]
			elsif transaction_error.policy_id == nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				edi_body = transaction_error.body.read
				eg_id = parse_edi_for_eg_id(edi_body)
				subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
				 		error_description]
			end
		rescue Exception=>e
			puts e.inspect
		end
	end
end

CSV.open("transaction_errors_ivl_dchbx_#{formatted_start_date}-#{formatted_end_date}.csv","w") do |csv|
	csv << ["Carrier","Transaction Kind", "Filename","BGN02","Policy ID","Subscriber HBX ID",
			"Submitted At Date", "Submitted At Time", "Ack/Nack Date", "Ack/Nack Time", "Market", "isa13",
			"Error Description"]
	dchl_ivl_errors.each do |transaction_error|
		count += 1
		if count % 1000 == 0
			puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
		end
		begin
			if transaction_error.policy_id != nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				policy = transaction_error.policy
				eg_id = policy.eg_id
				subscriber = find_subscriber(policy)
				subscriber_hbx_id = subscriber.try(:m_id)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
						error_description]
			elsif transaction_error.policy_id == nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				edi_body = transaction_error.body.read
				eg_id = parse_edi_for_eg_id(edi_body)
				subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
				 		error_description]
			end
		rescue Exception=>e
			puts e.inspect
		end
	end
end

CSV.open("transaction_errors_ivl_ddpa_#{formatted_start_date}-#{formatted_end_date}.csv","w") do |csv|
	csv << ["Carrier","Transaction Kind", "Filename","BGN02","Policy ID","Subscriber HBX ID",
			"Submitted At Date", "Submitted At Time", "Ack/Nack Date", "Ack/Nack Time", "Market", "isa13",
			"Error Description"]
	dd_ivl_errors.each do |transaction_error|
		count += 1
		if count % 1000 == 0
			puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
		end
		begin
			if transaction_error.policy_id != nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				policy = transaction_error.policy
				eg_id = policy.eg_id
				subscriber = find_subscriber(policy)
				subscriber_hbx_id = subscriber.try(:m_id)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
						error_description]
			elsif transaction_error.policy_id == nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				edi_body = transaction_error.body.read
				eg_id = parse_edi_for_eg_id(edi_body)
				subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
				 		error_description]
			end
		rescue Exception=>e
			puts e.inspect
		end
	end
end

CSV.open("transaction_errors_ivl_dtga_#{formatted_start_date}-#{formatted_end_date}.csv","w") do |csv|
	csv << ["Carrier","Transaction Kind", "Filename","BGN02","Policy ID","Subscriber HBX ID",
			"Submitted At Date", "Submitted At Time", "Ack/Nack Date", "Ack/Nack Time", "Market", "isa13",
			"Error Description"]
	dentegra_ivl_errors.each do |transaction_error|
		count += 1
		if count % 1000 == 0
			puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
		end
		begin
			if transaction_error.policy_id != nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				policy = transaction_error.policy
				eg_id = policy.eg_id
				subscriber = find_subscriber(policy)
				subscriber_hbx_id = subscriber.try(:m_id)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
						error_description]
			elsif transaction_error.policy_id == nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				edi_body = transaction_error.body.read
				eg_id = parse_edi_for_eg_id(edi_body)
				subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
				 		error_description]
			end
		rescue Exception=>e
			puts e.inspect
		end
	end
end

CSV.open("transaction_errors_ivl_dmnd_#{formatted_start_date}-#{formatted_end_date}.csv","w") do |csv|
	csv << ["Carrier","Transaction Kind", "Filename","BGN02","Policy ID","Subscriber HBX ID",
			"Submitted At Date", "Submitted At Time", "Ack/Nack Date", "Ack/Nack Time", "Market", "isa13",
			"Error Description"]
	dominion_ivl_errors.each do |transaction_error|
		count += 1
		if count % 1000 == 0
			puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
		end
		begin
			if transaction_error.policy_id != nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				policy = transaction_error.policy
				eg_id = policy.eg_id
				subscriber = find_subscriber(policy)
				subscriber_hbx_id = subscriber.try(:m_id)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
						error_description]
			elsif transaction_error.policy_id == nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				edi_body = transaction_error.body.read
				eg_id = parse_edi_for_eg_id(edi_body)
				subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
				 		error_description]
			end
		rescue Exception=>e
			puts e.inspect
		end
	end
end

# CSV.open("transaction_errors_ivl_gard_#{formatted_start_date}-#{formatted_end_date}.csv","w") do |csv|
# 	csv << ["Carrier","Transaction Kind", "Filename","BGN02","Policy ID","Subscriber HBX ID",
# 			"Submitted At Date", "Submitted At Time", "Ack/Nack Date", "Ack/Nack Time", "Market", "isa13",
# 			"Error Description"]
# 	guardian_ivl_errors.each do |transaction_error|
# 		count += 1
# 		if count % 1000 == 0
# 			puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
# 		end
# 		begin
# 			if transaction_error.policy_id != nil
# 				filename = transaction_error.body.to_s
# 				carrier_name = find_carrier_name_by_filename(filename)
# 				transmission = transaction_error.transmission
# 				transaction_kind = transaction_error.transaction_kind
# 				error_description = transaction_error.error_list
# 				bgn02 = transaction_error.bgn02
# 				policy = transaction_error.policy
# 				eg_id = policy.eg_id
# 				subscriber = find_subscriber(policy)
# 				subscriber_hbx_id = subscriber.try(:m_id)
# 				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
# 				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
# 				market = transmission.gs02
# 				isa13 = transmission.isa13
# 				ack_nack = transaction_error.try(:ack_nak_processed_at)
# 				if ack_nack != nil
# 					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
# 					ack_nack_time = ack_nack.strftime("%H:%M:%S")
# 				end
# 				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
# 						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
# 						error_description]
# 			elsif transaction_error.policy_id == nil
# 				filename = transaction_error.body.to_s
# 				carrier_name = find_carrier_name_by_filename(filename)
# 				transmission = transaction_error.transmission
# 				transaction_kind = transaction_error.transaction_kind
# 				error_description = transaction_error.error_list
# 				bgn02 = transaction_error.bgn02
# 				edi_body = transaction_error.body.read
# 				eg_id = parse_edi_for_eg_id(edi_body)
# 				subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
# 				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
# 				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
# 				market = transmission.gs02
# 				isa13 = transmission.isa13
# 				ack_nack = transaction_error.try(:ack_nak_processed_at)
# 				if ack_nack != nil
# 					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
# 					ack_nack_time = ack_nack.strftime("%H:%M:%S")
# 				end
# 				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
# 						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
# 				 		error_description]
# 			end
# 		rescue Exception=>e
# 			puts e.inspect
# 		end
# 	end
# end

CSV.open("transaction_errors_ivl_meta_#{formatted_start_date}-#{formatted_end_date}.csv","w") do |csv|
	csv << ["Carrier","Transaction Kind", "Filename","BGN02","Policy ID","Subscriber HBX ID",
			"Submitted At Date", "Submitted At Time", "Ack/Nack Date", "Ack/Nack Time", "Market", "isa13",
			"Error Description"]
	metlife_ivl_errors.each do |transaction_error|
		count += 1
		if count % 1000 == 0
			puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
		end
		begin
			if transaction_error.policy_id != nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				policy = transaction_error.policy
				eg_id = policy.eg_id
				subscriber = find_subscriber(policy)
				subscriber_hbx_id = subscriber.try(:m_id)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
						error_description]
			elsif transaction_error.policy_id == nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				edi_body = transaction_error.body.read
				eg_id = parse_edi_for_eg_id(edi_body)
				subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
				 		error_description]
			end
		rescue Exception=>e
			puts e.inspect
		end
	end
end

CSV.open("transaction_errors_ivl_no_carrier_name_#{formatted_start_date}-#{formatted_end_date}.csv","w") do |csv|
	csv << ["Carrier","Transaction Kind", "Filename","BGN02","Policy ID","Subscriber HBX ID",
			"Submitted At Date", "Submitted At Time", "Ack/Nack Date", "Ack/Nack Time", "Market", "isa13",
			"Error Description"]
	uncat_ivl_errors.each do |transaction_error|
		count += 1
		if count % 1000 == 0
			puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
		end
		begin
			if transaction_error.policy_id != nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				policy = transaction_error.policy
				eg_id = policy.eg_id
				subscriber = find_subscriber(policy)
				subscriber_hbx_id = subscriber.try(:m_id)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
						error_description]
			elsif transaction_error.policy_id == nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				edi_body = transaction_error.body.read
				eg_id = parse_edi_for_eg_id(edi_body)
				subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
				 		error_description]
			end
		rescue Exception=>e
			puts e.inspect
		end
	end
end

CSV.open("transaction_errors_shop_ghmsi_#{formatted_start_date}-#{formatted_end_date}.csv","w") do |csv|
	csv << ["Carrier","Transaction Kind", "Filename","BGN02","Policy ID","Subscriber HBX ID",
			"Submitted At Date", "Submitted At Time", "Ack/Nack Date", "Ack/Nack Time", "Market", "isa13",
			"Error Description"]
	carefirst_shp_errors.each do |transaction_error|
		count += 1
		if count % 1000 == 0
			puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
		end
		begin
			if transaction_error.policy_id != nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				policy = transaction_error.policy
				eg_id = policy.eg_id
				subscriber = find_subscriber(policy)
				subscriber_hbx_id = subscriber.try(:m_id)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
						error_description]
			elsif transaction_error.policy_id == nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				edi_body = transaction_error.body.read
				eg_id = parse_edi_for_eg_id(edi_body)
				subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
				 		error_description]
			end
		rescue Exception=>e
			puts e.inspect
		end
	end
end

CSV.open("transaction_errors_shop_ahi_#{formatted_start_date}-#{formatted_end_date}.csv","w") do |csv|
	csv << ["Carrier","Transaction Kind", "Filename","BGN02","Policy ID","Subscriber HBX ID",
			"Submitted At Date", "Submitted At Time", "Ack/Nack Date", "Ack/Nack Time", "Market", "isa13",
			"Error Description"]
	aetna_shp_errors.each do |transaction_error|
		count += 1
		if count % 1000 == 0
			puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
		end
		begin
			if transaction_error.policy_id != nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				policy = transaction_error.policy
				eg_id = policy.eg_id
				subscriber = find_subscriber(policy)
				subscriber_hbx_id = subscriber.try(:m_id)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
						error_description]
			elsif transaction_error.policy_id == nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				edi_body = transaction_error.body.read
				eg_id = parse_edi_for_eg_id(edi_body)
				subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
				 		error_description]
			end
		rescue Exception=>e
			puts e.inspect
		end
	end
end

CSV.open("transaction_errors_shop_kfmasi_#{formatted_start_date}-#{formatted_end_date}.csv","w") do |csv|
	csv << ["Carrier","Transaction Kind", "Filename","BGN02","Policy ID","Subscriber HBX ID",
			"Submitted At Date", "Submitted At Time", "Ack/Nack Date", "Ack/Nack Time", "Market", "isa13",
			"Error Description"]
	kaiser_shp_errors.each do |transaction_error|
		count += 1
		if count % 1000 == 0
			puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
		end
		begin
			if transaction_error.policy_id != nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				policy = transaction_error.policy
				eg_id = policy.eg_id
				subscriber = find_subscriber(policy)
				subscriber_hbx_id = subscriber.try(:m_id)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
						error_description]
			elsif transaction_error.policy_id == nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				edi_body = transaction_error.body.read
				eg_id = parse_edi_for_eg_id(edi_body)
				subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
				 		error_description]
			end
		rescue Exception=>e
			puts e.inspect
		end
	end
end

CSV.open("transaction_errors_shop_uhic_#{formatted_start_date}-#{formatted_end_date}.csv","w") do |csv|
	csv << ["Carrier","Transaction Kind", "Filename","BGN02","Policy ID","Subscriber HBX ID",
			"Submitted At Date", "Submitted At Time", "Ack/Nack Date", "Ack/Nack Time", "Market", "isa13",
			"Error Description"]
	united_shp_errors.each do |transaction_error|
		count += 1
		if count % 1000 == 0
			puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
		end
		begin
			if transaction_error.policy_id != nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				policy = transaction_error.policy
				eg_id = policy.eg_id
				subscriber = find_subscriber(policy)
				subscriber_hbx_id = subscriber.try(:m_id)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
						error_description]
			elsif transaction_error.policy_id == nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				edi_body = transaction_error.body.read
				eg_id = parse_edi_for_eg_id(edi_body)
				subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
				 		error_description]
			end
		rescue Exception=>e
			puts e.inspect
		end
	end
end

CSV.open("transaction_errors_shop_blhi_#{formatted_start_date}-#{formatted_end_date}.csv","w") do |csv|
	csv << ["Carrier","Transaction Kind", "Filename","BGN02","Policy ID","Subscriber HBX ID",
			"Submitted At Date", "Submitted At Time", "Ack/Nack Date", "Ack/Nack Time", "Market", "isa13",
			"Error Description"]
	bestlife_shp_errors.each do |transaction_error|
		count += 1
		if count % 1000 == 0
			puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
		end
		begin
			if transaction_error.policy_id != nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				policy = transaction_error.policy
				eg_id = policy.eg_id
				subscriber = find_subscriber(policy)
				subscriber_hbx_id = subscriber.try(:m_id)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
						error_description]
			elsif transaction_error.policy_id == nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				edi_body = transaction_error.body.read
				eg_id = parse_edi_for_eg_id(edi_body)
				subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
				 		error_description]
			end
		rescue Exception=>e
			puts e.inspect
		end
	end
end

CSV.open("transaction_errors_shop_dchbx_#{formatted_start_date}-#{formatted_end_date}.csv","w") do |csv|
	csv << ["Carrier","Transaction Kind", "Filename","BGN02","Policy ID","Subscriber HBX ID",
			"Submitted At Date", "Submitted At Time", "Ack/Nack Date", "Ack/Nack Time", "Market", "isa13",
			"Error Description"]
	dchl_shp_errors.each do |transaction_error|
		count += 1
		if count % 1000 == 0
			puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
		end
		begin
			if transaction_error.policy_id != nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				policy = transaction_error.policy
				eg_id = policy.eg_id
				subscriber = find_subscriber(policy)
				subscriber_hbx_id = subscriber.try(:m_id)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
						error_description]
			elsif transaction_error.policy_id == nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				edi_body = transaction_error.body.read
				eg_id = parse_edi_for_eg_id(edi_body)
				subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
				 		error_description]
			end
		rescue Exception=>e
			puts e.inspect
		end
	end
end

CSV.open("transaction_errors_shop_ddpa_#{formatted_start_date}-#{formatted_end_date}.csv","w") do |csv|
	csv << ["Carrier","Transaction Kind", "Filename","BGN02","Policy ID","Subscriber HBX ID",
			"Submitted At Date", "Submitted At Time", "Ack/Nack Date", "Ack/Nack Time", "Market", "isa13",
			"Error Description"]
	dd_shp_errors.each do |transaction_error|
		count += 1
		if count % 1000 == 0
			puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
		end
		begin
			if transaction_error.policy_id != nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				policy = transaction_error.policy
				eg_id = policy.eg_id
				subscriber = find_subscriber(policy)
				subscriber_hbx_id = subscriber.try(:m_id)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
						error_description]
			elsif transaction_error.policy_id == nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				edi_body = transaction_error.body.read
				eg_id = parse_edi_for_eg_id(edi_body)
				subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
				 		error_description]
			end
		rescue Exception=>e
			puts e.inspect
		end
	end
end

CSV.open("transaction_errors_shop_dtga_#{formatted_start_date}-#{formatted_end_date}.csv","w") do |csv|
	csv << ["Carrier","Transaction Kind", "Filename","BGN02","Policy ID","Subscriber HBX ID",
			"Submitted At Date", "Submitted At Time", "Ack/Nack Date", "Ack/Nack Time", "Market", "isa13",
			"Error Description"]
	dentegra_shp_errors.each do |transaction_error|
		count += 1
		if count % 1000 == 0
			puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
		end
		begin
			if transaction_error.policy_id != nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				policy = transaction_error.policy
				eg_id = policy.eg_id
				subscriber = find_subscriber(policy)
				subscriber_hbx_id = subscriber.try(:m_id)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
						error_description]
			elsif transaction_error.policy_id == nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				edi_body = transaction_error.body.read
				eg_id = parse_edi_for_eg_id(edi_body)
				subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
				 		error_description]
			end
		rescue Exception=>e
			puts e.inspect
		end
	end
end

CSV.open("transaction_errors_shop_dmnd_#{formatted_start_date}-#{formatted_end_date}.csv","w") do |csv|
	csv << ["Carrier","Transaction Kind", "Filename","BGN02","Policy ID","Subscriber HBX ID",
			"Submitted At Date", "Submitted At Time", "Ack/Nack Date", "Ack/Nack Time", "Market", "isa13",
			"Error Description"]
	dominion_shp_errors.each do |transaction_error|
		count += 1
		if count % 1000 == 0
			puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
		end
		begin
			if transaction_error.policy_id != nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				policy = transaction_error.policy
				eg_id = policy.eg_id
				subscriber = find_subscriber(policy)
				subscriber_hbx_id = subscriber.try(:m_id)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
						error_description]
			elsif transaction_error.policy_id == nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				edi_body = transaction_error.body.read
				eg_id = parse_edi_for_eg_id(edi_body)
				subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
				 		error_description]
			end
		rescue Exception=>e
			puts e.inspect
		end
	end
end

# CSV.open("transaction_errors_shop_gard_#{formatted_start_date}-#{formatted_end_date}.csv","w") do |csv|
# 	csv << ["Carrier","Transaction Kind", "Filename","BGN02","Policy ID","Subscriber HBX ID",
# 			"Submitted At Date", "Submitted At Time", "Ack/Nack Date", "Ack/Nack Time", "Market", "isa13",
# 			"Error Description"]
# 	guardian_shp_errors.each do |transaction_error|
# 		count += 1
# 		if count % 1000 == 0
# 			puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
# 		end
# 		begin
# 			if transaction_error.policy_id != nil
# 				filename = transaction_error.body.to_s
# 				carrier_name = find_carrier_name_by_filename(filename)
# 				transmission = transaction_error.transmission
# 				transaction_kind = transaction_error.transaction_kind
# 				error_description = transaction_error.error_list
# 				bgn02 = transaction_error.bgn02
# 				policy = transaction_error.policy
# 				eg_id = policy.eg_id
# 				subscriber = find_subscriber(policy)
# 				subscriber_hbx_id = subscriber.try(:m_id)
# 				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
# 				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
# 				market = transmission.gs02
# 				isa13 = transmission.isa13
# 				ack_nack = transaction_error.try(:ack_nak_processed_at)
# 				if ack_nack != nil
# 					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
# 					ack_nack_time = ack_nack.strftime("%H:%M:%S")
# 				end
# 				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
# 						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
# 						error_description]
# 			elsif transaction_error.policy_id == nil
# 				filename = transaction_error.body.to_s
# 				carrier_name = find_carrier_name_by_filename(filename)
# 				transmission = transaction_error.transmission
# 				transaction_kind = transaction_error.transaction_kind
# 				error_description = transaction_error.error_list
# 				bgn02 = transaction_error.bgn02
# 				edi_body = transaction_error.body.read
# 				eg_id = parse_edi_for_eg_id(edi_body)
# 				subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
# 				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
# 				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
# 				market = transmission.gs02
# 				isa13 = transmission.isa13
# 				ack_nack = transaction_error.try(:ack_nak_processed_at)
# 				if ack_nack != nil
# 					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
# 					ack_nack_time = ack_nack.strftime("%H:%M:%S")
# 				end
# 				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
# 						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
# 				 		error_description]
# 			end
# 		rescue Exception=>e
# 			puts e.inspect
# 		end
# 	end
# end

CSV.open("transaction_errors_shop_meta_#{formatted_start_date}-#{formatted_end_date}.csv","w") do |csv|
	csv << ["Carrier","Transaction Kind", "Filename","BGN02","Policy ID","Subscriber HBX ID",
			"Submitted At Date", "Submitted At Time", "Ack/Nack Date", "Ack/Nack Time", "Market", "isa13",
			"Error Description"]
	metlife_shp_errors.each do |transaction_error|
		count += 1
		if count % 1000 == 0
			puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
		end
		begin
			if transaction_error.policy_id != nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				policy = transaction_error.policy
				eg_id = policy.eg_id
				subscriber = find_subscriber(policy)
				subscriber_hbx_id = subscriber.try(:m_id)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
						error_description]
			elsif transaction_error.policy_id == nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				edi_body = transaction_error.body.read
				eg_id = parse_edi_for_eg_id(edi_body)
				subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
				 		error_description]
			end
		rescue Exception=>e
			puts e.inspect
		end
	end
end

CSV.open("transaction_errors_shop_no_carrier_name_#{formatted_start_date}-#{formatted_end_date}.csv","w") do |csv|
	csv << ["Carrier","Transaction Kind", "Filename","BGN02","Policy ID","Subscriber HBX ID",
			"Submitted At Date", "Submitted At Time", "Ack/Nack Date", "Ack/Nack Time", "Market", "isa13",
			"Error Description"]
	uncat_shp_errors.each do |transaction_error|
		count += 1
		if count % 1000 == 0
			puts "#{((count.to_d/total_transactions.to_d)*100.to_d)}% complete."
		end
		begin
			if transaction_error.policy_id != nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				policy = transaction_error.policy
				eg_id = policy.eg_id
				subscriber = find_subscriber(policy)
				subscriber_hbx_id = subscriber.try(:m_id)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
						error_description]
			elsif transaction_error.policy_id == nil
				filename = transaction_error.body.to_s
				carrier_name = find_carrier_name_by_filename(filename)
				transmission = transaction_error.transmission
				transaction_kind = transaction_error.transaction_kind
				error_description = transaction_error.error_list
				bgn02 = transaction_error.bgn02
				edi_body = transaction_error.body.read
				eg_id = parse_edi_for_eg_id(edi_body)
				subscriber_hbx_id = parse_edi_for_hbx_id(edi_body)
				submitted_at_date = transaction_error.submitted_at.strftime("%m-%d-%Y")
				submitted_at_time = transaction_error.submitted_at.strftime("%H:%M:%S")
				market = transmission.gs02
				isa13 = transmission.isa13
				ack_nack = transaction_error.try(:ack_nak_processed_at)
				if ack_nack != nil
					ack_nack_date = ack_nack.strftime("%m-%d-%Y")
					ack_nack_time = ack_nack.strftime("%H:%M:%S")
				end
				csv << [carrier_name, transaction_kind, filename.gsub("uploads/#{bgn02}_",""), bgn02, eg_id, subscriber_hbx_id,
						submitted_at_date,submitted_at_time,ack_nack_date,ack_nack_time, market, isa13,
				 		error_description]
			end
		rescue Exception=>e
			puts e.inspect
		end
	end
end
