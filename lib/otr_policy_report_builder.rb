require 'csv'

class OtrPolicyReportBuilder

  attr_reader :calender_year

  def initialize(calender_year)
    @calender_year = calender_year
  end

  def generate
    file_name = "#{Rails.root.to_s}/IVL_#{calender_year}_ORT_QHP_1095A_Data_#{Time.now.strftime("%m_%d_%Y_%H_%M")}.csv"
    CSV.open(file_name, "w", col_sep: "|") do |csv|
    
      @carriers = Carrier.all.inject({}){|hash, carrier| hash[carrier.id] = carrier.name; hash}
      @settings = YAML.load(File.read("#{Rails.root}/config/irs_settings.yml")).with_indifferent_access

      csv << headers
      current = 0
      index = 0

      policies_by_subscriber_1095a.each do |row, policies|
        policies.each do |policy|
          begin
            current += 1
            puts "at #{current}" if current % 100 == 0

            next if policy.kind == 'coverall'
            next unless valid_policy?(policy)

            input_builder = Generators::Reports::IrsInputBuilder.new(policy, { notice_type: "new"})
            input_builder.carrier_hash = @carriers
            input_builder.settings = @settings
            input_builder.process
            input_builder

            if policy.responsible_party_id.present?
              if responsible_party = Person.where("responsible_parties._id" => Moped::BSON::ObjectId.from_string(policy.responsible_party_id)).first
                puts "responsible party #{responsible_party.id} #{policy.id} address attached"          
                input_builder.append_recipient_address(responsible_party)
              else 
                raise "Responsible address missing!!"
              end
            end

            @notice = input_builder.notice

            if (@notice.recipient_address.to_s.match(/609 H St NE/i).present? || @notice.recipient_address.to_s.match(/1225 Eye St NW/i).present?)
              puts "#{@notice.recipient_address.to_s} #{@notice.policy_id}"
              next
            end

            @data = ['I', '1095A', 'DC', @notice.policy_id, @notice.issuer_name]
            @data += [@notice.recipient.try(:name), @notice.recipient.try(:ssn)]
            recipient_dob = @notice.try(:recipient).try(:dob).present? ? @notice.recipient.dob.gsub("/", "") : nil
            @data += [@notice.recipient.try(:ssn).present? ? nil : recipient_dob]
            if policy.responsible_party_id.present? || policy.applied_aptc.to_f == 0.0
              @data += [nil, nil, nil]
            else
              @data += [@notice.spouse.try(:name), @notice.spouse.try(:ssn)]
              spouse_dob = @notice.try(:spouse).try(:dob).present? ? @notice.spouse.dob.gsub("/", "") : nil
              @data += [@notice.try(:spouse).try(:ssn).present? ? nil : spouse_dob]
            end
            policy_start_date = policy.policy_start.present? ? policy.policy_start.strftime("%m%d%Y") : nil
            policy_end_date = policy.policy_end.present? ? policy.policy_end.strftime("%m%d%Y") : '12312021'
            @data += [policy_start_date, policy_end_date]
            @data += [@notice.recipient_address.street_1, @notice.recipient_address.street_2, @notice.recipient_address.city, @notice.recipient_address.state, @notice.recipient_address.zip, nil, nil, nil, nil, nil, nil, nil, nil]
            append_coverage_household
            append_premiums

            index += 1

            if (index % 100) == 0
              puts "found #{index} policies"
            end

            if @notice.covered_household.size > 5
              csv << @data
              @new_data = ['I', '1095A', 'DC', @notice.policy_id, @notice.issuer_name]
              @new_data += [@notice.recipient.try(:name), @notice.recipient.try(:ssn)]
              recipient_dob = @notice.try(:recipient).try(:dob).present? ? @notice.recipient.dob.gsub("/", "") : nil
              @new_data += [@notice.recipient.try(:ssn).present? ? nil : recipient_dob]
              if policy.responsible_party_id.present? || policy.applied_aptc.to_f == 0.0
                @new_data += [nil, nil, nil]
              else
                @new_data += [@notice.spouse.try(:name), @notice.spouse.try(:ssn)]
                spouse_dob = @notice.try(:spouse).try(:dob).present? ? @notice.spouse.dob.gsub("/", "") : nil
                @new_data += [@notice.try(:spouse).try(:ssn).present? ? nil : spouse_dob]
              end
              policy_start_date = policy.policy_start.present? ? policy.policy_start.strftime("%m%d%Y") : nil
              policy_end_date = policy.policy_end.present? ? policy.policy_end.strftime("%m%d%Y") : '12312021'
              @new_data += [policy_start_date, policy_end_date]
              @new_data += [@notice.recipient_address.street_1, @notice.recipient_address.street_2, @notice.recipient_address.city, @notice.recipient_address.state, @notice.recipient_address.zip, nil, nil, nil, nil, nil, nil, nil, nil]
              append_more_than_5_coverage_household
              append_premiums_more_than_5_members
              csv << @new_data
            else
              csv << @data
            end

          rescue Exception => e
            puts policy.id
            puts e.to_s.inspect
          end
        end
      end
    end
  end

  def headers
    columns = ['Record Type2', 'Form Type', 'Market Place ID', 'POLICY ID', 'ISSUER NAME']
    columns += ['Recipient Name', "Recipient's SSN", "Recipient's DOB", "Spouse Name", "Spouse SSN", "Spouse DOB"]
    columns += ["Policy Start Date", "Policy Termination Date"]
    columns += ["US Address 1", "US Address 2", "US City", "US State", "Zipcode", "US Zipcode extension", "Foreign Address 1", "Foreign Address 2", "Foreign City", "CountryCd", "Country", "Foreign Province", "Foreign Postal Code"]
    5.times {|i| columns += ["NAME#{i+1}", "SSN#{i+1}", "DOB#{i+1}", "BEGINDATE#{i+1}", "ENDDATE#{i+1}"]}
    12.times {|i| columns += ["PREMIUM#{i+1}", "SLCSP#{i+1}", "APTC#{i+1}"]}
    columns += ["Annual Total Premiums", "Annual Total (SLCAP) premium", "Annual Total APTC"]
    columns
  end

  def append_covered_member(indiv)
    indiv_dob = indiv.dob.present? ? indiv.dob.gsub("/", "") : nil
    indiv_start_date = indiv.coverage_start_date.present? ? indiv.coverage_start_date.gsub("/", "") : nil
    indiv_end_date = indiv.coverage_termination_date.present? ? indiv.coverage_termination_date.gsub("/", "") : nil
    @data += [indiv.name, indiv.ssn, indiv_dob, indiv_start_date, indiv_end_date]
  end

  def append_covered_more_than_5_member(indiv)
    indiv_dob = indiv.dob.present? ? indiv.dob.gsub("/", "") : nil
    indiv_start_date = indiv.coverage_start_date.present? ? indiv.coverage_start_date.gsub("/", "") : nil
    indiv_end_date = indiv.coverage_termination_date.present? ? indiv.coverage_termination_date.gsub("/", "") : nil
    @new_data += [indiv.name, indiv.ssn, indiv_dob, indiv_start_date, indiv_end_date]
  end

  def append_coverage_household
    @notice.covered_household.slice(0,5).each do |indiv|
      append_covered_member(indiv)
    end
    (5 - @notice.covered_household.slice(0,5).size).times{ append_blank_arr(5) }
  end

  def append_more_than_5_coverage_household
    @notice.covered_household.slice(5,10).each do |indiv|
      append_covered_more_than_5_member(indiv)
    end
    (5 - @notice.covered_household.slice(5,10).size).times{ append_blank_more_than_5_arr(5) }
  end

  def append_blank_arr(size)
    size.times{ @data << nil }
  end

  def append_blank_more_than_5_arr(size)
    size.times{ @new_data << nil }
  end

  def append_premiums
    total_premium_amount = "0.00"
    total_premium_amount_slcsp = "0.00"
    total_monthly_aptc = "0.00"
    (1..12).each do |index|
      monthly_premium = @notice.monthly_premiums.detect{|p| p.serial == index}
      if monthly_premium.blank?
        append_blank_arr(3)
        total_premium_amount = (as_dollars(total_premium_amount) + as_dollars("")).to_f
        total_premium_amount_slcsp = (as_dollars(total_premium_amount_slcsp) + as_dollars("")).to_f
        total_monthly_aptc = (as_dollars(total_monthly_aptc) + as_dollars("")).to_f
      else
        @data += [monthly_premium.premium_amount, monthly_premium.premium_amount_slcsp, monthly_premium.monthly_aptc]
        total_premium_amount = (as_dollars(total_premium_amount) + as_dollars(monthly_premium.premium_amount)).to_f
        total_premium_amount_slcsp = (as_dollars(total_premium_amount_slcsp) + as_dollars(monthly_premium.premium_amount_slcsp)).to_f
        total_monthly_aptc = (as_dollars(total_monthly_aptc) + as_dollars(monthly_premium.monthly_aptc)).to_f
      end
    end
    @data += [('%.2f' % total_premium_amount), ('%.2f' % total_premium_amount_slcsp), ('%.2f' % total_monthly_aptc)]
  end

  def append_premiums_more_than_5_members
    total_premium_amount = "0.00"
    total_premium_amount_slcsp = "0.00"
    total_monthly_aptc = "0.00"
    (1..12).each do |index|
      monthly_premium = @notice.monthly_premiums.detect{|p| p.serial == index}
      if monthly_premium.blank?
        append_blank_arr(3)
        total_premium_amount = (as_dollars(total_premium_amount) + as_dollars("")).to_f
        total_premium_amount_slcsp = (as_dollars(total_premium_amount_slcsp) + as_dollars("")).to_f
        total_monthly_aptc = (as_dollars(total_monthly_aptc) + as_dollars("")).to_f
      else
        @new_data += [monthly_premium.premium_amount, monthly_premium.premium_amount_slcsp, monthly_premium.monthly_aptc]
        total_premium_amount = (as_dollars(total_premium_amount) + as_dollars(monthly_premium.premium_amount)).to_f
        total_premium_amount_slcsp = (as_dollars(total_premium_amount_slcsp) + as_dollars(monthly_premium.premium_amount_slcsp)).to_f
        total_monthly_aptc = (as_dollars(total_monthly_aptc) + as_dollars(monthly_premium.monthly_aptc)).to_f
      end
    end
    @new_data += [('%.2f' % total_premium_amount), ('%.2f' % total_premium_amount_slcsp), ('%.2f' % total_monthly_aptc)]
  end
  
  def as_dollars(val)
    BigDecimal.new(val.to_s).round(2)
  end

  def rejected_policy?(policy)
    edi_transactions = Protocols::X12::TransactionSetEnrollment.where({ "policy_id" => policy.id })
    return true if edi_transactions.size == 1 && edi_transactions.first.aasm_state == 'rejected'
    false
  end

  def valid_policy?(policy)
    return false if policy.canceled?
    return false unless policy.plan.coverage_type =~ /health/i
    return false if policy.plan.metal_level =~ /catastrophic/i
    active_enrollees = policy.enrollees.reject{|en| en.canceled?}
    return false if active_enrollees.empty? || rejected_policy?(policy) || !policy.belong_to_authority_member?
    return false if policy.subscriber.coverage_end.present? && (policy.subscriber.coverage_end < policy.subscriber.coverage_start)
    true
  end

  def policies_by_subscriber_1095a
    plans = Plan.where({:metal_level => {"$not" => /catastrophic/i}, :coverage_type => /health/i}).map(&:id)

    p_repo = {}
    Person.no_timeout.each do |person|
      person.members.each do |member|
        p_repo[member.hbx_member_id] = person._id
      end
    end

    pols = PolicyStatus::Active.between(Date.new(calender_year-1,12,31), Date.new(calender_year,12,31)).results.where({
      :plan_id => {"$in" => plans}, :employer_id => nil
      }).group_by { |p| p_repo[p.subscriber.m_id] }
  end
end

