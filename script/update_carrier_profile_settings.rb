Carrier.all.each do |carrier|
  carrier.carrier_profiles.each do |ce_profile|
    ce_profile.update_attributes(requires_term_init_for_plan_change: true)
    puts "Updated term/drop setting to true for carrier profile #{ce_profile.fein}" unless ENV['RAILS_ENV'] == 'test'
  end
end

