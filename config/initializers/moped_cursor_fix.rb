module Moped
  class Collection
    def aggregate(*pipeline)
      pipeline.flatten!
      command = { aggregate: name.to_s, pipeline: pipeline, cursor: {} }
      val = database.session.command(command)
      AggregationCursor.new(database, name.to_s, database.session, val)
    end
  end
end
