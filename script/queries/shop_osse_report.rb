# Rake to run on production
# bundle exec rails r script/queries/shop_osse_report.rb -e production

require 'csv'
timey = Time.now
puts "Report started at #{timey}" unless Rails.env.test?

def as_dollars(val)
  BigDecimal.new(val.to_s).round(2)
end

yesterday_time = Date.yesterday.strftime("%Y%m%d")
today_time = Date.today.strftime("%Y%m%d")
CSV.open("osse_subsidy_report_#{yesterday_time}070000_#{today_time}070000.csv", 'w') do |csv|
  Policy.where(:created_at => {"$gte" => (Date.yesterday.to_time + 13.hours)}, is_osse: true).no_timeout.each do |pol|
    begin
      next unless pol.employer_id.present?
      total_premium_amount = pol.pre_amt_tot.to_f
      total_responsible_amount = pol.tot_res_amt.to_f
      employer_contribution = pol.tot_emp_res_amt.to_f
      aptc_amount = pol.applied_aptc.to_f
      osse_amount = as_dollars(total_premium_amount - employer_contribution - total_responsible_amount).to_f
      csv << [pol.try(:subscriber).try(:m_id), pol.eg_id, pol.policy_start.strftime("%Y-%m-%d"), ('%.2f' % osse_amount)]
    rescue StandardError => e
      puts "Unable to process enrollment #{enr.hbx_id} due to error #{e}"
    end
  end
  puts "End of the report" unless Rails.env.test?
end
