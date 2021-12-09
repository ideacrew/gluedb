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

  def self.coverage_inventory_for(person, filters = {})
    plans = select_filtered_plans(filters)
    Generators::CoverageInformationSerializer.new(person, plans).process
  end

  def self.select_filtered_plans(filters = {})
    filter_criteria = Hash.new
    if filters.has_key?(:hios_id)
      hios_regexp = /^#{filters[:hios_id]}/
      filter_criteria[:hios_plan_id] = hios_regexp
    end
    if filters.has_key?(:year)
      filter_criteria[:year] = filters[:year]
    end
    return nil if filter_criteria.empty?
    Plan.where(filter_criteria)
  end
end
