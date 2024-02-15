require 'csv'

class AuditPolicyReport

  attr_reader :calendar_year

  def initialize(calendar_year)
    @calendar_year = calendar_year
  end

  def generate
    file_name = "#{Rails.root.to_s}/IVL_#{calendar_year}_all_policies_#{Time.now.strftime("%m_%d_%Y_%H_%M")}.csv"
    CSV.open(file_name, "w") do |csv|
    
      @carriers = Carrier.all.inject({}){|hash, carrier| hash[carrier.id] = carrier.name; hash}
      @settings = YAML.load(File.read("#{Rails.root}/config/irs_settings.yml")).with_indifferent_access

      csv << ["POLICYID", "STATUS", "LASTNAME", "FIRSTNAME", "MI", "MEMBERID", "DOB", "GENDER", "DEPENDENTS", "PLANNAME", "PLANID", "METALLEVEL", "STARTDATE", "ENDDATE", "PREMIUM1", "APTC1", "PREMIUM2", "APTC2", "PREMIUM3", "APTC3", "PREMIUM4", "APTC4", "PREMIUM5", "APTC5", "PREMIUM6", "APTC6", "PREMIUM7", "APTC7", "PREMIUM8", "APTC8", "PREMIUM9", "APTC9", "PREMIUM10", "APTC10", "PREMIUM11", "APTC11", "PREMIUM12", "APTC12"]
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

            @data = [@notice.policy_id, policy.aasm_state]
            @data += [@notice.recipient.try(:name_last), @notice.recipient.try(:name_first), @notice.recipient.try(:name_middle)]
            recipient_dob = @notice.try(:recipient).try(:dob)
            recipient_gender = @notice.try(:recipient).try(:gender)
            @data += [@notice.recipient.hbx_id, recipient_dob, recipient_gender]
            @data += [policy.enrollees.reject { |k| k.rel_code == 'self' }.count]
            @data += [policy.try(:plan).try(:name), policy.try(:plan).try(:id), policy.try(:plan).try(:metal_level)]
            policy_start_date = policy.policy_start.present? ? policy.policy_start.strftime("%m/%d/%Y") : ''
            policy_end_date = policy.policy_end.present? ? policy.policy_end.strftime("%m/%d/%Y") : "12/31/#{calendar_year}"
            @data += [policy_start_date, policy_end_date]
            append_premiums

            index += 1

            if (index % 100) == 0
              puts "found #{index} policies"
            end

            csv << @data
          rescue Exception => e
            puts policy.id
            puts e.to_s.inspect
          end
        end
      end
    end
  end

  def append_blank_arr(size)
    size.times{ @data << '' }
  end

  def append_premiums
    (1..12).each do |index|
      monthly_premium = @notice.monthly_premiums.detect{|p| p.serial == index}
      if monthly_premium.blank?
        append_blank_arr(2)
      else
        @data += [monthly_premium.premium_amount, monthly_premium.monthly_aptc]
      end
    end
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
    return false if rejected_policy?(policy) || !policy.belong_to_authority_member?
    return false if policy.subscriber.coverage_end.present? && (policy.subscriber.coverage_end < policy.subscriber.coverage_start)
    true
  end

  def policies_by_subscriber_1095a
    plans = Plan.where(year: calendar_year).map(&:id)

    p_repo = {}
    Person.no_timeout.each do |person|
      person.members.each do |member|
        p_repo[member.hbx_member_id] = person._id
      end
    end

    pols = Policy.no_timeout.where({
      :enrollees => {"$elemMatch" => {
      "rel_code" => "self",
      :coverage_start => {"$gte" => Date.new(calendar_year, 1, 1), "$lte" => Date.new(calendar_year, 12, 31)}
    }},
      :employer_id => nil, :plan_id => {"$in" => plans}
    }).group_by { |p| p_repo[p.subscriber.m_id] }
  end
end

apr = AuditPolicyReport.new(2023)
apr.generate
