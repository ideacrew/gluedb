class SubscriberInventory
  def self.subscriber_ids_for(plan)
    aggregate_query_for_subscribers_under_plan(plan)
  end

  def self.aggregate_query_for_subscribers_under_plan(plan)
    Policy.collection.raw_aggregate([
      {"$match" => {"plan_id" => plan._id}},
      {"$unwind" => "$enrollees"},
      {"$match" => {"enrollees.rel_code" => "self"}},
      {"$group" => {"_id" => "$enrollees.m_id"}}
    ]).lazy.map do |rec|
      rec["_id"]
    end
  end

  # TODO: Implement coverage serialization as a JSON structure that
  #       matches what ACA Entities expects.
  def self.coverage_inventory_for(person)
    {}
  end
end
