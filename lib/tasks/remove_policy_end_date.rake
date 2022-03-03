require File.join(Rails.root,"app","data_migrations","remove_policy_end_date.rb")

# This rake tasks removes end dates from all members of a policy in Glue. 
# format RAILS_ENV=production bundle exec rake migrations:remove_policy_end_date aasm_state='submitted' eg_ids='123456,123444,123456' benefit_status='active'

namespace :migrations do 
  desc "Remove Policy End Date"
  RemovePolicyEndDate.define_task :remove_policy_end_date => :environment
end