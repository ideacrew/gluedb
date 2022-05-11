# Removes end dates from policies 
require File.join(Rails.root, "lib/mongoid_migration_task")

class RemovePolicyEndDate < MongoidMigrationTask
  def remove_end_dates(policy)
    policy.enrollees.each do |enrollee|
      enrollee.ben_stat = ENV['benefit_status']
      enrollee.emp_stat = "active"
      enrollee.coverage_status = "active"
      enrollee.coverage_end = nil
      enrollee.save!
    end
  end

  def change_aasm_state(policy)
    policy.aasm_state = ENV['aasm_state']
    policy.term_for_np = false
    policy.save!
  end

  def migrate
    eg_ids = ENV['eg_ids'].split(',').uniq
    eg_ids.each do |eg_id|
      policy = Policy.where(hbx_enrollment_ids: eg_id).first
      if policy.nil?
        puts "Policy not found with this eg_id: #{eg_id}"
      else
        begin
          remove_end_dates(policy)
          change_aasm_state(policy)
          puts "Removed end date from policy #{ENV['eg_id']}" unless Rails.env.test?
        rescue => e
          puts "Could not process policy with eg_id: #{eg_id}, error message: #{e.message}"
        end
      end
    end
  end
end
