module Moped
  class Collection
    def raw_aggregate(pipeline)
      command = { aggregate: name.to_s, pipeline: pipeline, cursor: {} }
      AggregationCursor.new(database, name.to_s, command)
    end
  end
end
