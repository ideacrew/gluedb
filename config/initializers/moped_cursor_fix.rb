module Moped
  class Collection
    def aggregate(*pipeline)
      pipeline.flatten!
      command = { aggregate: name.to_s, pipeline: pipeline, cursor: {} }
      AggregationCursor.new(database, name.to_s, command)
    end
  end
end
