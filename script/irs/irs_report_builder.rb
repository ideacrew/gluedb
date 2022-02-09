require 'spreadsheet'
require 'csv'

module Irs
  class IrsReportBuilder

    MONTHS = {
      1 => 'Jan',
      2 => 'Feb',
      3 => 'Mar',
      4 => 'Apr',
      5 => 'May',
      6 => 'Jun',
      7 => 'Jul',
      8 => 'Aug',
      9 => 'Sep',
      10 => 'Oct',
      11 => 'Nov',
      12 => 'Dec'
    }

    def export_excel
      @workbook = Spreadsheet::Workbook.new
      @sheet = @workbook.create_worksheet :name => 'report' 
      @count = 0

      build_1095a_report('1095a_excel.xls')
    end

    def irs_report_for_errors(irs_errors)
      CSV.open("#{Rails.root}/1095a_report_for_ids.csv", "wb") do |csv|
        csv << ["Sequence Number", "Error"] + column_names
        irs_errors.each do |irs_error|
          policy_id = irs_error[2]
          policy = Policy.find(policy_id)
          @notice = Generators::Reports::IrsInputBuilder.new(policy, multi_version_aptc?(policy), {report_type: 'h41_1095A'}).notice
          build_1095a_row(policy)
          csv << [irs_error[0], irs_error[1]] + @data
        end
      end
    end

    def export_csv
      @count = 0
      CSV.open("#{Rails.root}/1095a_report.csv", "wb") do |csv|
        csv << column_names
        CSV.foreach("#{Rails.root}/1095as_filtered.csv") do |row|
          policy = Policy.find(row[0].strip)
          begin
            active_enrollees = policy.enrollees.reject{|en| en.canceled?}
            next if active_enrollees.empty? || rejected_policy?(policy)
            next if [8026, 23120, 16245, 16246, 19203, 22375, 8376, 12057, 28798, 12153, 8642, 22015, 22167, 22168, 17584].include?(policy.id)
            @count += 1
            if @count % 50 == 0
              puts "---#{@count}"
            end
            # It helps to generate h41_1095A report. If needed h36 report then report_type value h41_1095A needs to be replaced with h36
            @notice = Generators::Reports::IrsInputBuilder.new(policy, multi_version_aptc?(policy), {report_type: 'h41_1095A'}).notice
            build_1095a_row(policy)
            csv << @data
          rescue Exception => e
            puts policy.id
          end
        end
      end
    end

    def column_names
      columns = ['POLICY ID', 'EG ID', 'CARRIER', 'HBX ID']
      5.times {|i| columns += ["NAME#{i+1}", "SSN#{i+1}", "DOB#{i+1}", "BEGINDATE#{i+1}", "ENDDATE#{i+1}"]}
      12.times {|i| columns += ["#{MONTHS[i+1]} PREMIUM", "#{MONTHS[i+1]} SLCSP", "#{MONTHS[i+1]} APTC"]}
      columns
    end

    def append_column_names
      @sheet.row(0).concat column_names
    end

    def build_1095a_report(file)
      append_column_names
      index = 1
      CSV.foreach("#{Rails.root}/1095as_filtered.csv") do |row|
        policy = Policy.find(row[0].strip)
        begin
          # next if policy.applied_aptc == 0

          active_enrollees = policy.enrollees.reject{|en| en.canceled?}
          next if active_enrollees.empty? || rejected_policy?(policy)
          # next unless multi_version_aptc?(policy)

          @count += 1
          if @count % 50 == 0 
            puts "---#{@count}"
          end
          # It helps to generate h41_1095A report. If needed h36 report then report_type value h41_1095A needs to be replaced with h36
          @notice = Generators::Reports::IrsInputBuilder.new(policy, multi_version_aptc?(policy), {report_type: 'h41_1095A'}).notice
          build_1095a_row(policy)
          @sheet.row(index).concat @data
        rescue Exception => e
          puts policy.id
        end
        index += 1
      end

      @workbook.write "#{Rails.root.to_s}/#{file}"
    end

    def export_as_1095a(policies, file)
      append_column_names
      index = 1
      policies.each do |policy|
        begin
          active_enrollees = policy.enrollees.reject{|en| en.canceled?}
          next if active_enrollees.empty?
          # It helps to generate h41_1095A report. If needed h36 report then report_type value h41_1095A needs to be replaced with h36
          @notice = Generators::Reports::IrsInputBuilder.new(policy, {report_type: 'h41_1095A'}).notice
          build_1095a_row
          @sheet.row(index).concat @data
        rescue Exception => e
          puts policy.id
        end
        index += 1
      end
      @workbook.write "#{Rails.root.to_s}/#{file}.xls"
    end

    def multi_version_aptc?(policy)
      if policy.version > 1
        aptcs = policy.versions.map(&:applied_aptc).map{ |x| x.to_f }
        if aptcs.uniq.size > 1 || (aptcs.uniq[0] != policy.applied_aptc.to_f)
          return true
        end
      end
      false
    end

    def rejected_policy?(policy)
      edi_transactions = Protocols::X12::TransactionSetEnrollment.where({ "policy_id" => policy.id })
      if edi_transactions.count == 1 && edi_transactions.first.aasm_state == 'rejected'
        return true
      end
      false
    end

    def export_policy_versions(policies, file)
      columns = ['POLICY ID', "HBX Member Id", "Coverage Start", "Coverage End", "Member Count", "APTC"]
      5.times {|i| columns += ["V#{i+1} Coverage Start", "V#{i+1} Coverage End", "V#{i+1} Member Count", "V#{i+1} APTC"]}
      @sheet.row(0).concat columns

      index = 1
      policies.each do |policy|
        begin
          @data = [ 
            policy.id,
            policy.subscriber.hbx_member_id,
            policy.subscriber.coverage_start.strftime("%m-%d-%Y"), 
            policy.subscriber.coverage_end.blank? ? nil : policy.subscriber.coverage_end.strftime("%m-%d-%Y"),
            policy.enrollees.reject{|en| en.canceled?}.size,
            policy.applied_aptc
          ]

          policy.versions.each do |version|
            @data += [
              version.subscriber.coverage_start.strftime("%m-%d-%Y"),
              version.subscriber.coverage_end.blank? ? nil : version.subscriber.coverage_end.strftime("%m-%d-%Y") ,
              version.enrollees.reject{|en| en.canceled?}.size,
              version.applied_aptc
            ]
          end

          @sheet.row(index).concat @data
        rescue Exception => e
          puts policy.id
        end
        index += 1
      end
      @workbook.write "#{Rails.root.to_s}/#{file}.xls"
    end

    def build_1095a_row(policy)
      @data = [ 
        @notice.policy_id,
        policy.eg_id,
        policy.plan.carrier.name,
        policy.subscriber.m_id
      ]
      append_coverage_household
      append_premiums
    end

    def append_covered_member(indiv)
      @data += [indiv.name, indiv.ssn, indiv.dob, indiv.coverage_start_date, indiv.coverage_termination_date]
    end

    def append_coverage_household
      @notice.covered_household.each do |indiv|
        append_covered_member(indiv)
      end
      (5 - @notice.covered_household.size).times{ append_blank_arr(5) }
    end

    def append_blank_arr(size)
      size.times{ @data << '' }
    end

    def append_premiums
      (1..12).each do |index|
        monthly_premium = @notice.monthly_premiums.detect{|p| p.serial == index}
        if monthly_premium.blank?
          append_blank_arr(3)
        else
          @data += [monthly_premium.premium_amount, monthly_premium.premium_amount_slcsp, monthly_premium.monthly_aptc]
        end
      end
    end
  end
end