#Usage
#rails r script/queries/steven_new.rb BEGIN-DATE -e production
#BEGIN-DATE, format = MMDDYYYY
#E.g. rails r script/queries/steven_new.rb "01012017" -e production

require 'csv'
timey = Time.now
puts "Report started at #{timey}"

begin
  @begin_date = Date.strptime(ARGV[0], "%m%d%Y")
  puts "begin_date #{@begin_date}"
rescue Exception => e
  puts "Error #{e.message}"
  puts "Usage:"
  puts "rails r script/queries/steven_new.rb BEGIN-DATE"
  puts "rails r script/queries/steven_new.rb 01012018"
  exit -1
end


policies = Policy.no_timeout.where(
  {"eg_id" => {"$not" => /DC0.{32}/},
   :enrollees => {"$elemMatch" =>
      {:rel_code => "self",
            :coverage_start => {"$gte" => @begin_date}}}}
)

policies = policies.reject{|pol| pol.market == 'individual' && 
                                 !pol.subscriber.nil? &&
                                 (pol.subscriber.coverage_start.year == 2014||
                                  pol.subscriber.coverage_start.year == 2015||
                                  pol.subscriber.coverage_start.year == 2016) }


def bad_eg_id(eg_id)
  (eg_id =~ /\A000/) || (eg_id =~ /\+/)
end

count = 0
total_count = policies.size

timestamp = Time.now.strftime('%Y%m%d%H%M')

Caches::MongoidCache.with_cache_for(Carrier, Plan, Employer) do
  CSV.open("stephen_expected_effectuated_20140930_#{timestamp}_ERRORS.csv", 'wb') do |e_csv|
    e_csv << ["Policy EG ID", "Policy ID", "Error", "Message", "Stacktrace"]
    CSV.open("stephen_expected_effectuated_20140930_#{timestamp}.csv", 'w') do |csv|
      csv << ["Subscriber ID", "Member ID" , "Policy ID", "Enrollment Group ID", "Status",
              "First Name", "Last Name","SSN", "DOB", "Gender", "Relationship",
              "Plan Name", "HIOS ID", "Plan Metal Level", "Carrier Name",
              "Premium Amount", "Premium Total", "Policy APTC", "Policy Employer Contribution",
              "Coverage Start", "Coverage End", "Benefit Status",
              "Employer Name", "Employer DBA", "Employer FEIN", "Employer HBX ID",
              "Home Address", "Mailing Address","Email","Phone Number","Broker"]
      policies.each do |pol|
        count += 1
        puts "#{count}/#{total_count} done at #{Time.now}" if count % 10000 == 0
        puts "#{count}/#{total_count} done at #{Time.now}" if count == total_count
        begin
          if !bad_eg_id(pol.eg_id)
            if !pol.subscriber.nil?
              #if !pol.subscriber.canceled?
                subscriber_id = pol.subscriber.m_id
                next if pol.subscriber.person.blank?
                subscriber_member = pol.subscriber.member
                auth_subscriber_id = subscriber_member.person.authority_member_id

                if !auth_subscriber_id.blank?
                  if subscriber_id != auth_subscriber_id
                    next
                  end
                end
                plan = Caches::MongoidCache.lookup(Plan, pol.plan_id) {
                  pol.plan
                }
                carrier = Caches::MongoidCache.lookup(Carrier, pol.carrier_id) {
                  pol.carrier
                }
                employer = nil
                if !pol.employer_id.blank?
                employer = Caches::MongoidCache.lookup(Employer, pol.employer_id) {
                  pol.employer
                }
                end
                if !pol.broker.blank?
                  broker = pol.broker.full_name
                end
                pol.enrollees.each do |en|
                  #if !en.canceled?
                    per = en.person
                    next if per.blank?
                    csv << [
                      subscriber_id, en.m_id, pol._id, pol.eg_id, pol.aasm_state,
                      per.name_first,
                      per.name_last,
                      en.member.ssn,
                      en.member.dob.strftime("%Y%m%d"),
                      en.member.gender,
                      en.rel_code,
                      plan.name, plan.hios_plan_id, plan.metal_level, carrier.name,
                      en.pre_amt, pol.pre_amt_tot,pol.applied_aptc, pol.tot_emp_res_amt,
                      en.coverage_start.blank? ? nil : en.coverage_start.strftime("%Y%m%d"),
                      en.coverage_end.blank? ? nil : en.coverage_end.strftime("%Y%m%d"),
                      en.ben_stat == "cobra" ? en.ben_stat : nil,
                      pol.employer_id.blank? ? nil : employer.name,
                      pol.employer_id.blank? ? nil : employer.dba,
                      pol.employer_id.blank? ? nil : employer.fein,
                      pol.employer_id.blank? ? nil : employer.hbx_id,
                      per.home_address.try(:full_address) || pol.subscriber.person.home_address.try(:full_address),
                      per.mailing_address.try(:full_address) || pol.subscriber.person.mailing_address.try(:full_address),
                      per.emails.first.try(:email_address), per.phones.first.try(:phone_number), broker
                    ]
                  #end
                end
              #end
            end
          end
        rescue Exception => e
          STDERR.puts("============ POLICY REPORT ERROR ============")
          STDERR.puts("Policy EG ID: #{pol.eg_id.to_s}")
          STDERR.puts("Policy ID: #{pol.id.to_s}")
          STDERR.puts("Kind: #{e.class}")
          STDERR.puts("Message: #{e.message}")
          STDERR.puts("Backtrace:")
          STDERR.puts(e.backtrace.join("\n"))
          e_csv << [pol.eg_id.to_s, pol.id.to_s, e.class, e.message, e.backtrace.join("\n")]
        end
      end
    end
  end
end

timey2 = Time.now
puts "Report ended at #{timey2}"
