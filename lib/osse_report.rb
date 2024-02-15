count = 0
batch_size = 1000
offset = 0
total_count = Policy.count
policy_ids = []

def as_dollars(val)
  BigDecimal.new(val.to_s).round(2)
end

CSV.open("osse_subsidy_report_#{Time.now.strftime("%Y%m%d%H%M%S")}.csv", 'w') do |csv|
  csv << ["Subscriber ID", "Policy ID", "Start Date", "Subsidy dollar amount"]
  while offset <= total_count
    Policy.offset(offset).limit(batch_size).no_timeout.each do |pol|
      count += 1
      total_premium_amount = pol.pre_amt_tot.to_f
      total_responsible_amount = pol.tot_res_amt.to_f
      employer_contribution = pol.tot_emp_res_amt.to_f
      aptc_amount = pol.applied_aptc.to_f
      osse_amount = if pol.employer_id.present?
                      as_dollars(total_premium_amount - employer_contribution -  total_responsible_amount).to_f
                    else
                      as_dollars(total_premium_amount - aptc_amount -  total_responsible_amount).to_f
                    end
      begin
        csv << [pol.try(:subscriber).try(:m_id), pol.eg_id, pol.try(:policy_start), ('%.2f' % osse_amount)]
      rescue StandardError => e
        puts "Unable to process enrollment #{enr.hbx_id} due to error #{e}"
      end
    end
    offset += batch_size
    puts "#{count}/#{total_count} done at #{Time.now}" if count % 10_000 == 0
    puts "#{count}/#{total_count} done at #{Time.now}" if count == total_count
  end
  puts "End of the report" unless Rails.env.test?
end
