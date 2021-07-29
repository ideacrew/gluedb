class Address
  include Mongoid::Document
  include Mongoid::Timestamps
  include MergingModel

  TYPES = %W(home work mailing)

  field :address_type, type: String
  field :address_1, type: String
  field :address_2, type: String, default: ""
  field :address_3, type: String, default: ""
  field :city, type: String
  field :county, type: String
  field :state, type: String
  field :location_county_code, type: String
  field :location_state_code, type: String
  field :zip, type: String
  field :zip_extension, type: String
  field :country_name, type: String, default: ""
  field :full_text, type: String

  validates_inclusion_of :address_type, in: TYPES, message: "Invalid type"

  validates_presence_of :address_1, :city, :state, :zip

  validates_format_of :zip, :with => /^\d{5}(-\d{4})?$/, :message => "should be in the form 12345 or 12345-1234"

  embedded_in :person, :inverse_of => :addresses
  embedded_in :employer, :inverse_of => :addresses
  embedded_in :broker, :inverse_of => :addresses
  # embeds_one :location

  before_save :clean_fields

  def location
    nil #todo
  end

  def clean_fields
    attrs_to_clean = [:address_type, :address_1, :address_2, :city, :state, :zip]
    attrs_to_clean.each do |a|
      self[a].strip! unless self[a].blank?
    end
  end

  def match(another_address)
    return(false) if another_address.nil?
    attrs_to_match = [:address_type, :address_1, :address_2, :city, :state, :zip, :location_county_code]
    attrs_to_match.all? { |attr| attribute_matches?(attr, another_address) }
  end

  def same_location?(another_address)
    return(false) if another_address.nil?
    attrs_to_match = [:address_1, :address_2, :city, :state, :zip]
    attrs_to_match.all? { |attr| attribute_matches?(attr, another_address) }
  end

  def attribute_matches?(attribute, other)
    return true if (self[attribute].blank? && other[attribute].blank?)
    safe_downcase(self[attribute]) == safe_downcase(other[attribute])
  end

  def formatted_address
    city.present? ? city_delim = city + "," : city_delim = city
    line3 = [city_delim, state, zip].reject(&:nil? || empty?).join(' ')
    [address_1, address_2, line3].reject(&:nil? || empty?).join('<br/>').html_safe
  end

  def full_address
    city.present? ? city_delim = city + "," : city_delim = city
    [address_1, address_2, city_delim, state, zip].reject(&:nil? || empty?).join(' ')
  end

  # NOTE: searching won't help -- dynamically called in PersonParser using send
  def merge_update(m_address)
    merge_with_overwrite(m_address,
      :address_1,
      :address_2,
      :city,
      :state,
      :zip,
      :location_county_code
    )
  end

  def home?
    "home" == self.address_type.downcase
  end

  def self.make(data)
    address = Address.new
    address.address_type = data[:type]
    address.address_1 = data[:street1]
    address.address_2 = data[:street2]
    address.city = data[:city]
    address.state = data[:state]
    address.zip = data[:zip]
    address
  end

  private

  def safe_downcase(val)
    val.nil? ? nil : val.downcase
  end

end
