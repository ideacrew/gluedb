class CarrierProfile
  include Mongoid::Document
  include Mongoid::Timestamps

  embedded_in :carrier

  field :fein, type: String
  field :profile_name, type: String
  field :requires_term_init_for_plan_change, type: Boolean, default: false
end
