namespace :ct_demo do
  desc "Load Demo Users"
  task :load_data => ["ct_demo:load_carriers","ct_demo:load_users"]
end