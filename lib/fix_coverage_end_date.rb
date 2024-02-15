policies = Policy.where(:aasm_state.in => ["canceled", "terminated"])
count = 0
batch_size = 1000
offset = 0
total_count = policies.size

CSV.open("#{Rails.root}/policy_coverage_dates_update_info.csv", "w", force_quotes: true) do |csv|
  csv << ["EG_ID", "Policy Start Date", "Policy End Date", "AASM State", "Enrollee ID", "Enrollee StartDate Before update", "Enrollee EndDate Before update", "Enrollee StartDate After update", "Enrollee EnDate After update", "reason"]
  while offset <= total_count
    policies.offset(offset).limit(batch_size).no_timeout.each do |pol|
      count += 1
      next if ["1189755", "1204058", "1204150", "1212042"].include?(pol.eg_id)
      begin
        pol.enrollees.each do |en|
          next if en.rel_code == 'self'
          case pol.aasm_state
          when "canceled"
            if en.coverage_start.nil? && en.coverage_end.present?
              before_end = en.coverage_end.strftime("%m/%d/%Y")
              before_start = en.coverage_start
              en.update_attributes!(coverage_start: before_end, emp_stat: "terminated", coverage_status: "inactive")
              after_start = en.coverage_start.strftime("%m/%d/%Y")
              after_end = en.coverage_end.strftime("%m/%d/%Y")
              csv << [pol.eg_id, pol.policy_start.try(:to_s), pol.policy_end.try(:to_s), pol.aasm_state, en.m_id, before_start, before_end, after_start, after_end, "cancel start"]
            elsif en.coverage_end.nil? && en.coverage_start.present?
              before_start = en.coverage_start.strftime("%m/%d/%Y")
              before_end = en.coverage_end
              en.update_attributes!(coverage_end: before_start, emp_stat: "terminated", coverage_status: "inactive")
              after_start = en.coverage_start.strftime("%m/%d/%Y")
              after_end = en.coverage_end.strftime("%m/%d/%Y")
              csv << [pol.eg_id, pol.policy_start.try(:to_s), pol.policy_end.try(:to_s), pol.aasm_state, en.m_id, before_start, before_end, after_start, after_end, "cancel end"]
            elsif en.coverage_end < en.coverage_start
              before_start = en.coverage_start.strftime("%m/%d/%Y")
              before_end = en.coverage_end.strftime("%m/%d/%Y")
              en.update_attributes!(coverage_end: before_start, emp_stat: "terminated", coverage_status: "inactive")
              after_start = en.coverage_start.strftime("%m/%d/%Y")
              after_end = en.coverage_end.strftime("%m/%d/%Y")
              csv << [pol.eg_id, pol.policy_start.try(:to_s), pol.policy_end.try(:to_s), pol.aasm_state, en.m_id, before_start, before_end, after_start, after_end, "cancel start end"]
            end
          when "terminated"
            sub_start = pol.subscriber.coverage_start.strftime("%m/%d/%Y")
            sub_end = pol.subscriber.coverage_end.strftime("%m/%d/%Y")
            if en.coverage_start.nil? && en.coverage_end.present?
              before_end = en.coverage_end.strftime("%m/%d/%Y")
              before_start = en.coverage_start
              en.update_attributes!(coverage_start: sub_start, emp_stat: "terminated", coverage_status: "inactive")
              after_start = en.coverage_start.strftime("%m/%d/%Y")
              after_end = en.coverage_end.strftime("%m/%d/%Y")
              csv << [pol.eg_id, pol.policy_start.try(:to_s), pol.policy_end.try(:to_s), pol.aasm_state, en.m_id, before_start, before_end, after_start, after_end, "term start"]
            elsif en.coverage_end.nil? && en.coverage_start.present?
              before_start = en.coverage_start.strftime("%m/%d/%Y")
              before_end = en.coverage_end
              en.update_attributes!(coverage_end: sub_end, emp_stat: "terminated", coverage_status: "inactive")
              after_start = en.coverage_start.strftime("%m/%d/%Y")
              after_end = en.coverage_end.strftime("%m/%d/%Y")
              csv << [pol.eg_id, pol.policy_start.try(:to_s), pol.policy_end.try(:to_s), pol.aasm_state, en.m_id, before_start, before_end, after_start, after_end, "term end"]
            elsif en.coverage_end < en.coverage_start
              before_start = en.coverage_start.strftime("%m/%d/%Y")
              before_end = en.coverage_end.strftime("%m/%d/%Y")
              en.update_attributes!(coverage_end: sub_end, emp_stat: "terminated", coverage_status: "inactive")
              after_start = en.coverage_start.strftime("%m/%d/%Y")
              after_end = en.coverage_end.strftime("%m/%d/%Y")
              csv << [pol.eg_id, pol.policy_start.try(:to_s), pol.policy_end.try(:to_s), pol.aasm_state, en.m_id, before_start, before_end, after_start, after_end, "term start end"]
            end
          end
        end
      rescue Exception => e
        puts e.message
        puts "issue with this policy eg_id: #{pol.eg_id}"
      end
    end
    offset += batch_size
    puts "#{count}/#{total_count} done at #{Time.now}" if count % 10_000 == 0
    puts "#{count}/#{total_count} done at #{Time.now}" if count == total_count
  end
end
