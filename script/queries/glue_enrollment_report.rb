#Usage
#rails r script/queries/glue_enrollment_report.rb BEGIN-DATE -e production
#BEGIN-DATE, format = MMDDYYYY
#E.g. rails r script/queries/glue_enrollment_report.rb "09102022" -e production

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
    csv << ["Subscriber ID", "Member ID" , "Policy ID", "Enrollment Group ID", "Status", "NPT Flag",
            "First Name", "Last Name","SSN", "DOB", "Gender", "Relationship",
            "Rating Area", "Plan Name", "HIOS ID", "Plan Metal Level", "Carrier Member ID",
            "Carrier Policy ID", "Carrier Name", "Premium Amount", "Premium Total", "Policy APTC",
            "Policy Employer Contribution", "Coverage Start", "Coverage End", "Benefit Status",
            "Employer Name", "Employer DBA", "Employer FEIN", "Employer HBX ID", "Home Address", "Home county code",
            "Mailing Address", "Mailing county code", "Email", "Phone Number", "Broker", "Broker NPN", "Enrollment Chain IDs",
            "aptc_0", "aptc_1", "aptc_2", "aptc_3", "aptc_4", "aptc_5", "aptc_6", "aptc_7", "Responsible Party ID",
            "RP hbx_id", "RP First Name", "RP Middle Name", "RP Last Name", "RP Full Name", "RP SSN", "RP DOB",
            "RP Gender", "RP Address Type", "RP Full Address", "RP Address Count", "RP location county code", "RP Phone Type",
            "RP Phone Number", "RP Phone Count"]
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
              broker = pol.broker
              broker_name = broker.full_name
              broker_npn = broker.npn
            else
              broker_name = nil
              broker_npn = nil
            end
            pol.enrollees.each do |en|
              #if !en.canceled?
                per = en.person
                next if per.blank?
                data = [
                  subscriber_id, en.m_id, pol._id, pol.eg_id, pol.aasm_state,
                  pol.term_for_np,
                  per.name_first,
                  per.name_last,
                  en.member.ssn,
                  en.member.dob.strftime("%Y%m%d"),
                  en.member.gender,
                  en.rel_code]

                data += [
                  Settings.site.short_name == "DC HealthLink" ? 'R-DC001' : pol.rating_area,
                  plan.name, plan.hios_plan_id, plan.metal_level, en.c_id, en.cp_id, carrier.name,
                  en.pre_amt, pol.pre_amt_tot,pol.applied_aptc, pol.tot_emp_res_amt,
                  en.coverage_start.blank? ? nil : en.coverage_start.strftime("%Y%m%d"),
                  en.coverage_end.blank? ? nil : en.coverage_end.strftime("%Y%m%d"),
                  en.ben_stat == "cobra" ? en.ben_stat : nil,
                  pol.employer_id.blank? ? nil : employer.name,
                  pol.employer_id.blank? ? nil : employer.dba,
                  pol.employer_id.blank? ? nil : employer.fein,
                  pol.employer_id.blank? ? nil : employer.hbx_id,
                  per.home_address.try(:full_address) || pol.subscriber.person.home_address.try(:full_address),
                  per.home_address.try(:location_county_code) || pol.subscriber.person.home_address.try(:location_county_code),
                  per.mailing_address.try(:full_address) || pol.subscriber.person.mailing_address.try(:full_address),
                  per.mailing_address.try(:location_county_code) || pol.subscriber.person.mailing_address.try(:location_county_code),
                  per.emails.first.try(:email_address), per.phones.first.try(:phone_number), broker_name, broker_npn]

                aptc_credits = pol.aptc_credits.sort_by(&:start_on).map do |i|
                  "start_on: #{i.start_on} -- end_on: #{i.end_on} -- aptc: #{i.aptc} -- pre_amt_tot: #{i.pre_amt_tot} -- tot_res_amt: #{i.tot_res_amt}"
                end

                data += [pol.hbx_enrollment_ids, aptc_credits[0], aptc_credits[1], aptc_credits[2], aptc_credits[3], aptc_credits[4],
                         aptc_credits[5], aptc_credits[6], aptc_credits[7]]
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
                      res_location_county_code = res_address.try(:location_county_code)
                    else
                      res_addresses_count = '0'
                      res_full_address = nil
                      res_address_type = nil
                      res_location_county_code = nil
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
                    data += [responsible_party_id, res_hbx_id, res_first_name, res_middle_name, res_last_name, res_full_name, res_ssn, res_dob, res_gender,
                             res_address_type, res_full_address, res_addresses_count, res_location_county_code, res_phone_type, res_phone_number, res_phone_count]
                  else
                    data += [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
                  end
                else
                  data += [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
                end
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
