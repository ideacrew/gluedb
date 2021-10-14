namespace :ct_demo do
  desc "Load Demo Users"
  task :load_users => :environment do
    admin_user = User.new({
      email: "admin@dc.gov",
      role: "admin",
      approved: true
    })
    admin_user.save(validate: false)
    User.where({email: "admin@dc.gov"}).update_all({"$set" => {encrypted_password: "$2a$10$cg1txu.K24FFlg6fX0EJGuXffFS8BxD4pZDHo8EyfFHf/P9.qtysK"}})
  end
end