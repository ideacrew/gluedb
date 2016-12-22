class EmployerEvent
  include Mongoid::Document
  include Mongoid::Timestamps

  field :event_time, type: Time
  field :event_name, type: String
  field :resource_body, type: String
  field :employer_id, type: String

  XML_NS = "http://openhbx.org/api/terms/1.0"

  index({event_time: 1, event_name: 1, employer_id: 1})

  def self.newest_event?(new_employer_id, new_event_name, new_event_time)
    !self.where(:employer_id => new_employer_id, :event_name => new_event_name, :event_time => {"$gte" => new_event_time}).any?
  end

  def self.store_and_yield_deleted(new_employer_id, new_event_name, new_event_time, new_payload)
    new_event = self.create!({
      employer_id: new_employer_id,
      event_name: new_event_name,
      event_time: new_event_time,
      resource_body: new_payload
    })
    self.where(:employer_id => new_employer_id, :event_name => new_event_name, :_id => {"$ne" => new_event._id}).each do |old_record|
      yield old_record
      old_record.destroy
    end
  end

  def self.get_digest_for(carrier)
    events = self.order_by(event_time: 1)
    carrier_file = EmployerEvents::CarrierFile.new(carrier)
    events.each do |ev|
      event_renderer = EmployerEvents::Renderer.new(ev)
      carrier_file.render_event_using(event_renderer)
    end
    carrier_file.result
  end

end
