module ChangeSets
  class PersonAddressChangeSet
    attr_reader :address_kind

    include ::ChangeSets::SimpleMaintenanceTransmitter

    def initialize(addy_kind)
      @address_kind = addy_kind
    end

    def perform_update(person, person_update, policies_to_notify, transmit = true)
      new_address = person_update.addresses.detect { |au| au.address_type == address_kind }
      old_address = person.addresses.detect { |au| au.address_type == address_kind }
      home_address = person.addresses.detect { |au| au.address_type == "home" }
      update_result = false
      if new_address.nil?
        person.remove_address_of(address_kind)
        update_result = person.save
      else
        person.set_address(Address.new(new_address.to_hash))
        update_result = person.save
      end
      changed_to_address = person.addresses.detect { |au| au.address_type == address_kind }
      return false unless update_result
      return true if skip_notification?(old_address, changed_to_address, home_address)
      notify_policies("change", edi_change_reason, person_update.hbx_member_id, policies_to_notify, cv_change_reason)
      true
    end

    # Circumstances under which we should skip notification - mailing address only
    def skip_notification?(old_address, new_address, home_address)
      return false if address_kind != "mailing"
      return false if home_address.blank?
      return true if old_address.blank? && addresses_match?(home_address, new_address)
      return true if new_address.blank? && addresses_match?(home_address, old_address)
      only_county_fips_changed?(old_address, new_address)
    end

    def addresses_match?(address_1, address_2)
      return true if address_1.blank? && address_2.blank?
      return false if address_1.blank? || address_2.blank?
      address_1.same_location?(address_2)
    end

    def only_county_fips_changed?(old_address, new_address)
      return false if old_address.blank? || new_address.blank?
      old_address.same_location?(new_address)
    end

    def edi_change_reason
      (address_kind == "home") ? "change_of_location" : "personnel_data"
    end

    def cv_change_reason 
      (address_kind == "home") ? "urn:openhbx:terms:v1:enrollment#change_member_address" : "urn:openhbx:terms:v1:enrollment#change_member_communication_numbers"
    end

    def applicable?(person, person_update)
      resource_address = person_update.addresses.detect { |adr| adr.address_kind == @address_kind }
      record_address = person.addresses.detect { |adr| adr.address_type == @address_kind }
      items_changed?(resource_address, record_address)
    end

    def items_changed?(resource_item, record_item)
      return false if (resource_item.nil? && record_item.nil?)
      return true if record_item.nil?
      !record_item.match(resource_item)
    end
  end
end
