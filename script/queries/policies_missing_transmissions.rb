ct_cache = Caches::Mongoid::SinglePropertyLookup.new(Plan, "coverage_type")

all_pol_ids = Protocols::X12::TransactionSetHeader.collection.aggregate([
  {"$match" => {
    "policy_id" => { "$ne" => nil },
    "created_at" => { "$gte" => (Date.today - 3.years).to_time}
  }},
  { "$group" => { "_id" => "$policy_id" }}
]).map { |val| val["_id"] }

# No cancels/terms in this batch!
pols_2015 = Policy.where(
  "created_at" => { "$gte" => (Date.today - 2.years).to_time}
).no_timeout

puts pols_2015.length

untransmitted_pols = []

if File.exists?("policy_blacklist.txt")
  excluded_policies = File.read("policy_blacklist.txt").split("\n").map(&:strip).map(&:to_i)
else
  excluded_policies = []
end

timestamp = Time.now.strftime('%Y%m%d%H%M')

CSV.open("policies_without_transmissions_#{timestamp}.csv","w") do |csv|
  csv << ["Created At", "Enrollment Group ID", "Carrier", "Employer", "Subscriber Name", "Subscriber HBX ID"]
  pols_2015.each do |pol|
    if !all_pol_ids.include?(pol.id)
      if pol.subscriber.present? && !pol.canceled?
        unless excluded_policies.include? pol.id
          created_at = pol.created_at
          eg_id = pol.eg_id
          carrier = pol.plan.carrier.abbrev
          employer = pol.try(:employer).try(:name)
          subscriber_name = pol.subscriber.person.full_name rescue ""
          subscriber_hbx_id = pol.subscriber.m_id
          csv << [created_at,eg_id,carrier,employer,subscriber_name,subscriber_hbx_id]
        end
      end
    end
  end
end
