class SubscriberInventory
  def self.subscriber_ids_for(carrier_hios, year)
    plans = plans_for(carrier_hios, year)
    aggregate_query_for_subscribers_under_plans(plans)
  end

  def self.aggregate_query_for_subscribers_under_plans(plans)
    Policy.collection.raw_aggregate([
      {"$match" => {"plan_id" => {"$in" => plans.map(&:_id)}}},
      {"$unwind" => "$enrollees"},
      {"$match" => {"enrollees.rel_code" => "self"}},
      {"$group" => {"_id" => "$enrollees.m_id"}}
    ]).lazy.map do |rec|
      rec["_id"]
    end
  end

  def self.plans_for(carrier_hios, year)
    hios_regexp = /^#{carrier_hios}/
    Plan.where({
      year: year,
      hios_plan_id: hios_regexp
    })
  end

  def self.coverage_inventory_for(person)
    Generators::CoverageInformationSerializer.new(person).process
  end
end
