class Person
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Versioning
  # include Mongoid::Paranoia

  extend Mongorder

  attr_accessor :relationship

  field :name_pfx, type: String, default: ""
  field :name_first, type: String
  field :name_middle, type: String, default: ""
  field :name_last, type: String
  field :name_sfx, type: String, default: ""
  field :name_full, type: String
  field :alternate_name, type: String, default: ""
  field :updated_by, type: String, default: "system_service"
  field :job_title, type: String, default: ""
  field :department, type: String, default: ""
  field :is_active, type: Boolean, default: true

  # We've moved to a many-to-many
  # field :family, type: Moped::BSON::ObjectId

  # TODO: reference authority member by Mongo ID
  # field :family, type: Moped::BSON::ObjectId
  field :authority_member_id, type: String, default: nil
  index({"authority_member_id" => 1})

  # field :auth_member, type: Moped::BSON::ObjectId
  # index({auth_member: 1})

  before_create :initialize_authority_member
  before_save :initialize_name_full
  before_save :invalidate_find_caches

  validates_presence_of :name_first, :name_last
  index({name_last:  1})
  index({name_first: 1})
  index({name_last:1, name_first: 1})
  index({name_first: 1, name_last:1})
  index({name_first: 1, name_last:1, "members.dob"=> 1})
  index({name_last:1, name_first: 1, "members.dob" => 1})
  index({name_first: 1, name_last:1, "emails.email_address" => 1})
  index({name_last: 1, name_first:1, "emails.email_address" => 1})
  index({"emails.email_address" => 1})

  #TODO - create authority member index (use Mongo indexing method that expects many empty values)

  # has_and_belongs_to_many :employers, class_name: "Employer", inverse_of: :employees
  belongs_to :employer, class_name: "Employer", inverse_of: :employees, index: true

  embeds_many :addresses, :inverse_of => :person
  accepts_nested_attributes_for :addresses, reject_if: proc { |attribs| attribs['address_1'].blank? }, allow_destroy: true

  embeds_many :phones, :inverse_of => :person
  accepts_nested_attributes_for :phones, reject_if: proc { |attribs| attribs['phone_number'].blank? }, allow_destroy: true

  embeds_many :emails, :inverse_of => :person
  accepts_nested_attributes_for :emails, reject_if: proc { |attribs| attribs['email_address'].blank? }, allow_destroy: true

  # embeds_many :members, after_add: :generate_hbx_member_id
  embeds_many :members, cascade_callbacks: true

  embeds_many :person_relationships
  accepts_nested_attributes_for :person_relationships

  embeds_many :responsible_parties
#  accepts_nested_attributes_for :responsible_parties, reject_if: :all_blank, allow_destroy: true

  embeds_many :comments
  accepts_nested_attributes_for :comments, reject_if: proc { |attribs| attribs['content'].blank? }, allow_destroy: true

  index({"members.hbx_member_id" =>1})
  index({"members.ssn" => 1})
  index({"members.dob" => 1})
  accepts_nested_attributes_for :members, reject_if: :all_blank, allow_destroy: true

  scope :all_under_age_twenty_six, ->{ gt(:'members.dob' => (Date.today - 26.years))}
  scope :all_over_age_twenty_six,  ->{lte(:'members.dob' => (Date.today - 26.years))}

  # TODO: Add scope that accepts age range
  # scope :all_between_age_range, ->(range) {}

  scope :all_over_or_equal_age, ->(age) {lte(:'members.dob' => (Date.today - age.years))}
  scope :all_under_or_equal_age, ->(age) {gte(:'members.dob' => (Date.today - age.years))}
  scope :all_with_multiple_members, exists({ :'members.1' => true })
  scope :by_name, order_by(name_last: 1, name_first: 1)

  def families
    Family.where(:family_members.person_id => self.id).to_a
  end

  def update_attributes_with_delta(props = {})
    old_record = self.find(self.id)
    self.assign_attributes(props)
    delta = self.changes_with_embedded
    return false unless self.valid?
    # As long as we call right here, whatever needs to be notified,
    # with the following three arguments:
    # - the old record
    # - the properties to update ("props")
    # - the delta ("delta")
    # We have everything we need to construct whatever messages care about that data.
    # E.g. (again, ignore the naming as it is terrible)
    #Protocols::Notifier.update_notification(old_record, props, delta)
    Protocols::Notifier.update_notification(old_record, delta) #The above statement was giving error with 3 params

    # Then we proceed normally
    self.update_attributes(props)
  end

  def is_authoritative?
    self.members.any?{|m| m.authority?}
  end

  def is_authority_member?(m_id)
    return true if self.members.length < 2
    m_id == self.authority_member_id
  end

  def associate_all_policies_and_employers_and_brokers
    self.members.each do |m|
      Policy.find_all_policies_for_member_id(m.hbx_member_id).each do |pol|
        self.policies  << pol
        self.employers << pol.employer
        self.brokers   << pol.broker
      end
    end
    save!
  end

  def self.find_for_members(member_ids)
    Queries::PersonMemberQuery.new(member_ids).execute
  end

  def self.with_over_age_child_enrollments
    # Return set of People > 26 years old and listed on policies as child relationship code
    Person.all_over_age_twenty_six.find_all { |p| p.has_over_age_child_enrollment? }
  end

  def has_over_age_child_enrollment?
    members.any? { |m| m.policies_with_over_age_children.size > 0 }
  end

  def no_deleting_authority_member
    errors.add(:base, "members may not be deleted if they are the authority") if (members.any? { |m| m.authority && !m.deleted_at.blank? } )
  end

  def invalidate_find_caches
    members.each do |m|
      Rails.cache.delete("Person/find/members.hbx_member_id.#{m.hbx_member_id}")
    end
    true
  end

  def self.default_search_order
    [
      ["name_last", 1],
      ["name_first", 1]
    ]
  end

  def self.search_hash(s_str)
    clean_str = s_str.strip
    s_rex = Regexp.new(Regexp.escape(clean_str), true)
    additional_exprs = []
    if clean_str.include?(" ")
      parts = clean_str.split(" ").compact
      first_re = Regexp.new(Regexp.escape(parts.first), true)
      last_re = Regexp.new(Regexp.escape(parts.last), true)
      additional_exprs << {:name_first => first_re, :name_last => last_re}
    end
    {
      "$or" => ([
        {"name_first" => s_rex},
        {"name_middle" => s_rex},
        {"name_last" => s_rex},
        {"members.hbx_member_id" => s_rex},
        {"members.ssn" => s_rex}
      ] + additional_exprs)
    }
  end

  def self.match_for_ssn(m_ssn, nf, nl, d_of_b)
    Queries::ExistingPersonQuery.new(m_ssn, nf, d_of_b).find
  end

  def self.find_for_member_id(m_id)
    Queries::PersonByHbxIdQuery.new(m_id).execute
  end

  def policies
    query_proxy.policies
  end

  def authority_member=(hbx_id)
    self.authority_member_id = hbx_id
    self.authority_member
  end

  def authority_member
    return self.members.first if members.length < 2
    members.detect { |m| m.hbx_member_id == self.authority_member_id }
  end

  def full_name
    [name_pfx, name_first, name_middle, name_last, name_sfx].reject(&:blank?).join(' ').downcase.gsub(/\b\w/) {|first| first.upcase }
  end

  def merge_member(m_member)
    found_member = self.members.detect { |m| m.hbx_member_id == m_member.hbx_member_id }
    if !found_member.nil?
      found_member.merge_member(m_member)
    else
      self.members << m_member
      #assign_authority_member_id #Don't allow merge to wipe authority member id's
    end
  end

  def assign_authority_member_id
    self.authority_member_id = (self.members.length > 1) ? nil : self.members.first.hbx_member_id
  end

  def merge_address(m_address)
    unless (self.addresses.any? { |p| p.match(m_address) })
      self.addresses << m_address
    end
  end

  def update_address(m_address)
    existing_address = self.addresses.select { |p| p.address_type == m_address.address_type }
    existing_address.each do |ep|
      self.addresses.delete(ep)
    end
    self.addresses << m_address
    self.touch
  end

  def remove_phone_of(phone_type)
    existing_phone = self.phones.select { |p| p.phone_type == phone_type }
    existing_phone.each do |em|
      self.phones.delete(em)
    end
    self.touch
  end

  def remove_email_of(email_type)
    existing_email = self.emails.select { |p| p.email_type == email_type }
    existing_email.each do |em|
      self.emails.delete(em)
    end
    self.touch
  end

  def remove_address_of(address_type)
    existing_address = self.addresses.select { |p| p.address_type == address_type }
    existing_address.each do |em|
      self.addresses.delete(em)
    end
    self.touch
  end

  def merge_email(m_email)
    unless (self.emails.any? { |p| p.match(m_email) })
      self.emails << m_email
    end
  end

  def update_email(m_email)
    existing_email = self.emails.select { |p| p.email_type == m_email.email_type }
    existing_email.each do |ep|
      self.emails.delete(ep)
    end
    self.emails << m_email
    self.touch
  end

  def merge_phone(m_phone)
    unless (self.phones.any? { |p| p.match(m_phone) })
      self.phones << m_phone
    end
  end

  def update_phone(m_phone)
    existing_phones = self.phones.select { |p| p.phone_type == m_phone.phone_type }
    existing_phones.each do |ep|
      self.phones.delete(ep)
    end
    self.phones << m_phone
    self.touch
  end

  # Assimilate person doc into this instance
  def merge(person_id)
  end

  # Extract list of members into new, separate Person doc
  def split(member_id_list)
  end

  def unsafe_save!
    Person.skip_callback(:save, :before, :revise)
    save(validate: false)
    Person.set_callback(:save, :before, :revise)
  end


  def addresses_match?(other_person)
    my_home_addresses = addresses.select(&:home?)
    other_home_addresses = other_person.addresses.select(&:home?)
    return(false) if (my_home_addresses.length != other_home_addresses.length)
    my_home_addresses.all? do |m_addy|
      other_home_addresses.any? { |o_addy| o_addy.match(m_addy) }
    end
  end

  def home_address
    addresses.detect { |adr| adr.address_type == "home" }
  end

  def mailing_address
    addresses.detect { |adr| adr.address_type == "mailing"} || home_address
  end

  def home_phone
    phones.detect { |adr| adr.phone_type == "home" }
  end

  def home_email
    emails.detect { |adr| adr.email_type == "home" }
  end

  def initialize_name_full
    self.name_full = full_name
  end

  def can_edit_family_address?
    associated_ids = associated_for_address
    return(true) if associated_ids.length < 2
    Person.find(associated_ids).combination(2).all? do |addr_set|
      addr_set.first.addresses_match?(addr_set.last)
    end
  end

  def active_policies
    Policy.find_active_and_unterminated_for_members_in_range(self.members.map(&:hbx_member_id), Date.today, Date.today)
  end

  def future_active_policies
    person_future_active_policies = []
    member_ids = self.members.map(&:hbx_member_id)

    member_ids.each do |member_id|
      person_future_active_policies.concat(policies.select { |p| p.future_active_for?(member_id) })
    end
    person_future_active_policies
  end

  def associated_for_address
    other_ids = policies.map(&:enrollees).flatten.map(&:person).map(&:_id)
    ([self._id] + other_ids).uniq
  end

  def families
    query_proxy.families
  end

  def relationships_in_group
    group = families.first
    group.person_relationships.select { |r| r.object_person == id }
  end

  def employee_roles
    policies_through_employer = policies.select { |p| !p.employer_id.nil? && !p.canceled? }
    enrollees = []
    policies_through_employer.each do |p|
        enrollees << p.enrollees.detect { |e| self.members.map(&:hbx_member_id).include?(e.m_id) }
    end
    enrollees
  end

  def billing_address
    billing_addr = addresses.detect { |adr| adr.address_type == "billing" }
    if (billing_addr.nil?)
      home_address
    else
      billing_addr
    end

  end

  def address_of(location)
    addresses.detect { |a| a.address_type == location }
  end

  def self.find_by_id(id)
    where(id: id).first
  end

  def self.find_by_member_id(member_id)
    Person.find_for_members([member_id]).first
  end

  def set_address(new_address)
    address_collection = self.addresses.reject { |p| p.address_type == new_address.address_type }
    full_addresses = address_collection + (new_address.nil? ? [] : [new_address])
    self.addresses = full_addresses
    self.touch
  end

  def set_phone(new_phone)
    phone_collection = self.phones.reject { |p| p.phone_type == new_phone.phone_type}
    full_phones = phone_collection + [new_phone]
    self.phones = full_phones
    self.touch
  end

  def set_email(new_email)
    email_collection = self.emails.reject { |p| p.email_type == new_email.email_type }
    full_emails = email_collection + [new_email]
    self.emails = full_emails
    self.touch
  end

  def merge_relationship(new_rel)
    old_relationships = self.person_relationships.select do |rel|
      rel.relative_id == new_rel.relative_id
    end
    old_relationships.each do |old_rel|
      self.person_relationships.delete(old_rel)
    end

    relationship = self.person_relationships.build({relative: new_rel.relative, kind: new_rel.kind})
    relationship.save
    self.save
    self.touch
    self.reload
  end

  def find_relationship_with(other_person)

    relationship = person_relationships.detect do |person_relationship|
      person_relationship.relative_id == other_person.id
    end

    if relationship
      return relationship.kind
    else
      return nil
    end
  end

  private

  def initialize_authority_member
    self.authority_member = members.first.hbx_member_id if members.count == 1
  end

  def query_proxy
    @query_proxy ||= Queries::PersonAssociations.new(self)
  end
end
