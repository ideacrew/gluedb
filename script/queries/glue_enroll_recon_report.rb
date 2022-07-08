#Steps to execute the rake
# 1. Place the enroll enrollment report csv file on the glue root
# 2. We need to pass a file as an arugument i.e "enroll_enrollment_report.csv" to generate a new report
# rake: RAILS_ENV=production bundle exec rails r script/queries/glue_enroll_recon_report.rb enroll_enrollment_report.csv

require 'csv'
timey = Time.now
puts "Report started at #{timey}"

file_name = "#{Rails.root}/enroll_enrollment_report.csv"

if ARGV.length != 1
  puts "Error: enroll enrollment file is missing, please pass it arguments"
  exit
end

if File.exists?(ARGV[0]) && "#{Rails.root}/#{ARGV[0]}" == file_name
  timestamp = Time.now.strftime('%Y%m%d%H%M')
  CSV.open("glue_enroll_recon_report_#{timestamp}.csv", 'w') do |csv|
    csv << ["Primary Member ID", "Member ID", "Policy ID", "Policy Last Updated", "Policy Subscriber ID", "Status",
              "Member Status", "First Name", "Last Name","SSN", "DOB", "Age", "Gender", "Relationship", "Benefit Type",
              "Tobacco Status", "Plan Name", "HIOS ID", "Plan Metal Level", "Carrier Name", "Rating Area",
              "Premium Amount", "Premium Total", "Policy APTC", "Responsible Premium Amt", "FPL",
              "Purchase Date", "Coverage Start", "Coverage End",
              "Home Address", "Mailing Address","Work Email", "Home Email", "Phone Number","Broker", "Broker NPN",
              "Broker Assignment Date", "Race", "Ethnicity", "Citizen Status", "Broker Assisted",
              "In Glue", "Glue eg_id", "Glue policy status", "Glue NPT status","Glue Total Premium", "Glue APTC value",
              "Glue Responsible Amt ", "Glue Rating area", "Glue Policy start", "Glue Policy End", "Glue Broker",
              "Glue created timestamp", "Glue last modified timestamp", "Glue Tobacco status", "Glue Enrollee Member ID",
              "Glue Enrollee Premium amt", "Glue Enrollee Start Date", "Glue Enrollee End Date"]

    CSV.foreach(file_name, headers: true).each do |row|
      hbx_enrollment_id = row["Policy ID"]
      member_id = row["Member ID"]
      begin
        pol = Policy.where(hbx_enrollment_ids: hbx_enrollment_id).first
        if pol.present?
          broker = pol.broker.present? ? pol.broker.full_name : nil
          in_glue = pol.present?
          person = Person.where(authority_member_id: member_id).first
          enrollee = pol.enrollees.where(m_id: member_id).first
          member_premium_amount = enrollee.present? ? enrollee.pre_amt.to_f : nil
          member_start_date = enrollee.present? ? enrollee.coverage_start.to_s : nil
          member_end_date = enrollee.present? ? enrollee.coverage_end.to_s : nil
          tobacco_use = person.present? ? person.try(:authority_member).try(:hlh) : nil
          csv << [row["Primary Member ID"], row["Member ID"], row["Policy ID"], row["Policy Last Updated"],
                  row["Policy Subscriber ID"], row["Status"], row["Member Status"], row["First Name"], row["Last Name"],
                  row["SSN"], row["DOB"], row["Age"], row["Gender"], row["Relationship"], row["Benefit Type"],
                  row["Tobacco Status"], row["Plan Name"], row["HIOS ID"], row["Plan Metal Level"],
                  row["Carrier Name"], row["Rating Area"], row["Premium Amount"], row["Premium Total"],
                  row["Policy APTC"], row["Responsible Premium Amt"], row["FPL"], row["Purchase Date"],
                  row["Coverage Start"], row["Coverage End"], row["Home Address"], row["Mailing Address"],
                  row["Work Email"], row["Home Email"], row["Phone Number"], row["Broker"], row["Broker NPN"],
                  row["Broker Assignment Date"], row["Race"], row["Ethnicity"], row["Citizen Status"], row["Broker Assisted"],
                  in_glue, pol.eg_id, pol.aasm_state, pol.term_for_np, pol.pre_amt_tot, pol.applied_aptc, 
                  pol.tot_res_amt, pol.rating_area, pol.policy_start, pol.policy_end, broker, pol.created_at.to_s,
                  pol.updated_at.to_s, tobacco_use, enrollee.try(:m_id), member_premium_amount, member_start_date, member_end_date]
        else
          csv << [row["Primary Member ID"], row["Member ID"], row["Policy ID"], row["Policy Last Updated"],
                  row["Policy Subscriber ID"], row["Status"], row["Member Status"], row["First Name"], row["Last Name"],
                  row["SSN"], row["DOB"], row["Age"], row["Gender"], row["Relationship"], row["Benefit Type"],
                  row["Tobacco Status"], row["Plan Name"], row["HIOS ID"], row["Plan Metal Level"],
                  row["Carrier Name"], row["Rating Area"], row["Premium Amount"], row["Premium Total"],
                  row["Policy APTC"], row["Responsible Premium Amt"], row["FPL"], row["Purchase Date"],
                  row["Coverage Start"], row["Coverage End"], row["Home Address"], row["Mailing Address"],
                  row["Work Email"], row["Home Email"], row["Phone Number"], row["Broker"], row["Broker NPN"],
                  row["Broker Assignment Date"], row["Race"], row["Ethnicity"], row["Citizen Status"], row["Broker Assisted"],
                  false, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
        end
      rescue => e
        puts "#{e.message}, hbx_enrollment_id:#{hbx_enrollment_id}"
      end
    end
  end
else
  puts "Error: Provided file path is not valid or provided file is having issues with either file format"
end

timey2 = Time.now
puts "Report ended at #{timey2}"
