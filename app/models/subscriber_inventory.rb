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
    ]).map do |rec|
      rec["_id"]
    end
  end
end
