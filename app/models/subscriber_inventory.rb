class SubscriberInventory
  def self.subscriber_ids_for(filters)
    plan_ids = select_filtered_plan_ids(filters)
    aggregate_query_for_subscribers_under_plans(plan_ids)
  end

  def self.aggregate_query_for_subscribers_under_plans(plan_ids)
    Policy.collection.raw_aggregate([
      {"$match" => {"plan_id" => {"$in" => plan_ids}}},
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

  def self.coverage_inventory_for(person, filters = {})
    plan_ids = select_filtered_plan_ids(filters)
    Generators::CoverageInformationSerializer.new(person, plan_ids).process
  end

  def self.select_filtered_plan_ids(filters = {})
    filter_criteria = Hash.new
    if filters.has_key?(:hios_id)
      hios_regexp = /^#{filters[:hios_id]}/
      filter_criteria[:hios_plan_id] = hios_regexp
    end
    if filters.has_key?(:year)
      filter_criteria[:year] = filters[:year]
    end
    return [] if filter_criteria.empty?

    Rails.cache.fetch("plan-ids-#{filter_criteria[:hios_plan_id]}-#{filter_criteria[:year]}", expires_in: 24.hour) do
      plans = Plan.where(filter_criteria)
      plans.pluck(:_id)
    end
  end
end

