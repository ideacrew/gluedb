# This rake task imports plans and rates into glue

# Examples
# RAILS_ENV=production bundle exec rake import:plans_and_rates[2014]

namespace :import do
  desc 'Load Plans and Rates'
  task :plans_and_rates, [:active_year] => :environment do |t, args|
    year = args[:active_year]

    puts "Importing #{year} plans"
    plan_file = File.open("db/seedfiles/#{year}_plans.json", 'r')
    data = plan_file.read
    plan_file.close

    plan_data = JSON.load(data)
    puts "Before: total #{Plan.count} plans"
    puts "#{plan_data.size} plans in json file"

    plan_data.each do |pd|
      pd['carrier_id'] = Carrier.for_fein(pd['fein']).id.to_s
      plan = Plan.where(year: year.to_i).and(hios_plan_id: pd['hios_plan_id']).first

      if pd['renewal_plan_hios_id'].present?
        pd['renewal_plan_id'] = Plan.where(year: pd['year'].to_i + 1, hios_plan_id: pd['renewal_plan_hios_id']).first.try(:id)
      end

      if plan.blank?
        plan = Plan.new(pd)
        plan.id = pd['id']
        plan.save!
      else
        new_data = pd.dup
#        new_data.delete('id')
        plan.update_attributes(new_data)
      end

      if plan.carrier.blank?
        raise "carrier_ids are not correct for plans: #{plan.hios_id}"
      end

    end
    puts "After: total #{Plan.count} plans"
    puts "Finished importing #{year} plans"
  end
end
