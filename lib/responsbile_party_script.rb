field_names  = %w(policy_id eg_id policy_start_year policy_state responsible_party_id carrier_name coverage_type first_name middle_name last_name full_name authority_member_id ssn dob full_address address_type addresses_count )
CSV.open("#{Rails.root}/responsibility_party_records.csv", "w", force_quotes: true) do |csv|
  csv << field_names
  policies = Policy.where({
    :enrollees => {"$elemMatch" => {
    "rel_code" => "self",
    :coverage_start => {"$gte" => Date.new(2021, 1, 1)}
  }},
    :employer_id => nil, "responsible_party_id" => {"$ne" => nil}
  })
  policies.no_timeout.each do |pol|
    carrier_name = pol.try(:carrier).try(:name)
    coverage_type = pol.try(:coverage_type)
    person = Person.where("responsible_parties._id" => pol.responsible_party_id).first
    auth_mem = person.authority_member
    if person.authority_member.present?
      hbx_id = auth_mem.try(:hbx_member_id)
      ssn = auth_mem.try(:ssn)
      dob = auth_mem.try(:dob)
    else
      hbx_id = nil
      ssn = nil
      dob = nil
    end
    first_name = person.try(:name_first)
    middle_name = person.try(:name_middle)
    last_name = person.try(:name_last)
    full_name = person.try(:name_full)
    eg_id = pol.try(:eg_id)
    policy_id = pol.id.to_s
    responsible_party_id = pol.responsible_party_id
    policy_start_year = pol.try(:policy_start)
    if person.addresses.count > 0
      addresses_count = person.addresses.count
      address = person.addresses.first
      full_address = address.full_address
      address_type = address.address_type
    else
      addresses_count = nil
      full_address = nil
      address_type = nil
    end
    csv << [policy_id, eg_id, policy_start_year, pol.aasm_state, responsible_party_id, carrier_name, coverage_type,first_name, middle_name, last_name, full_name, hbx_id, ssn, dob, full_address, address_type, addresses_count]
  end
end

