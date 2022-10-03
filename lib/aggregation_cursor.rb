class AggregationCursor
  include Enumerable

  def initialize(database, collection, command)
    @database = database
    @collection = collection
    @session = database.session
    @command = command
    @node = @session.context.with_node do |node|
      node
    end
  end

  def initialize_result
    result = @session.command(@command)
    @first_batch = result["cursor"]["firstBatch"]
    @cursor_id = result["cursor"]["id"]
  end

  def each
    initialize_result
    @first_batch.each { |doc| yield doc }
    while more?
      documents = get_more
      documents.each { |doc| yield doc }
    end
  end

  def get_more
    reply = @node.get_more @database, @collection, @cursor_id, request_limit
    @cursor_id = reply.cursor_id
    reply.documents
  end

  def more?
    @cursor_id != 0
  end
end
