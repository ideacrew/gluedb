#Usage
#rails r script/queries/glue_enrollment_report.rb BEGIN-DATE -e production
#BEGIN-DATE, format = MMDDYYYY
#E.g. rails r script/queries/glue_enrollment_report.rb "11012021" -e production

require 'csv'
timey = Time.now
puts "Report started at #{timey}"

begin
  @begin_date = Date.strptime(ARGV[0], "%m%d%Y")
  puts "begin_date #{@begin_date}"
rescue Exception => e
  puts "Error #{e.message}"
  puts "Usage:"
  puts "rails r script/queries/glue_enrollment_report.rb BEGIN-DATE"
  puts "example: rails r script/queries/glue_enrollment_report.rb 11012021"
  exit
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

  CSV.open("glue_enrollment_report_#{timestamp}.csv", 'w') do |csv|
    csv << ["Subscriber ID", "Member ID" , "Policy ID", "Enrollment Group ID", "Status",
            "First Name", "Last Name","SSN", "DOB", "Gender", "Relationship", "Responsible Party ID",
            "RP hbx_id", "RP First Name", "RP Middle Name", "RP Last Name", "RP Full Name", "RP SSN", "RP DOB",
            "RP Gender", "RP Address Type", "RP Full Address", "RP Address Count", "RP Phone Type",
            "RP Phone Number", "RP Phone Count", "Rating Area", "Plan Name", "HIOS ID", "Plan Metal Level",
            "Carrier ID", "Carrier Name", "Premium Amount", "Premium Total", "Policy APTC",
            "Policy Employer Contribution", "Coverage Start", "Coverage End", "Benefit Status",
            "Employer Name", "Employer DBA", "Employer FEIN", "Employer HBX ID",
            "Home Address", "Mailing Address","Email","Phone Number","Broker"]
    policies.each do |pol|
      count += 1
      puts "#{count}/#{total_count} done at #{Time.now}" if count % 10000 == 0
      puts "#{count}/#{total_count} done at #{Time.now}" if count == total_count
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
                data = [
                  subscriber_id, en.m_id, pol._id, pol.eg_id, pol.aasm_state,
                  per.name_first,
                  per.name_last,
                  en.member.ssn,
                  en.member.dob.strftime("%Y%m%d"),
                  en.member.gender,
                  en.rel_code]

                if pol.responsible_party_id.present?
                  person = Person.where("responsible_parties._id" => pol.responsible_party_id).first
                  unless person.nil?
                    auth_mem = person.authority_member
                    if auth_mem.present?
                      res_hbx_id = auth_mem.try(:hbx_member_id)
                      res_ssn = auth_mem.try(:ssn)
                      res_dob = auth_mem.try(:dob)
                      res_gender = auth_mem.try(:gender)
                    else
                      res_hbx_id = nil
                      res_ssn = nil
                      res_dob = nil
                      res_gender = nil
                    end
                    res_first_name = person.try(:name_first)
                    res_middle_name = person.try(:name_middle)
                    res_last_name = person.try(:name_last)
                    res_full_name = person.try(:name_full)
                    responsible_party_id = pol.responsible_party_id
                    if person.addresses.count > 0
                      res_addresses_count = person.addresses.count
                      res_address = person.addresses.first
                      res_full_address = res_address.try(:full_address)
                      res_address_type = res_address.try(:address_type)
                    else
                      res_addresses_count = '0'
                      res_full_address = nil
                      res_address_type = nil
                    end
                    if person.phones.count > 0
                      res_phone_count = person.phones.count
                      res_phone = person.phones.first
                      res_phone_type = res_phone.try(:phone_type)
                      res_phone_number = res_phone.try(:phone_number)
                    else
                      res_phone_count = '0'
                      res_phone_type = nil
                      res_phone_number = nil
                    end
                    data += [responsible_party_id, res_hbx_id, res_first_name, res_middle_name, res_last_name, res_full_name, res_ssn, res_dob, res_gender, res_address_type, res_full_address, res_addresses_count, res_phone_type, res_phone_number, res_phone_count]
                  else
                    data += [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
                  end
                else
                  data += [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
                end

                data += [
                    Settings.site.short_name == "DC HealthLink" ? 'R-DC001' : pol.rating_area,
                    plan.name, plan.hios_plan_id, plan.metal_level, carrier.id, carrier.name,
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
               csv << data
              #end
            end
          #end
        end
      end
    end
  end

end

timey2 = Time.now
puts "Report ended at #{timey2}"
