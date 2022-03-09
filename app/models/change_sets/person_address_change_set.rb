module ChangeSets
  class PersonAddressChangeSet
    attr_reader :address_kind

    include ::ChangeSets::SimpleMaintenanceTransmitter

    def initialize(addy_kind)
      @address_kind = addy_kind
    end

    def perform_update(person, person_update, policies_to_notify, transmit = true)
      new_address = person_update.addresses.detect { |au| au.address_type == address_kind }
      update_result = false
      if new_address.nil?
        person.remove_address_of(address_kind)
        update_result = person.save
      else
        person.set_address(Address.new(new_address.to_hash))
        update_result = person.save
      end
      return false unless update_result
      notify_policies("change", edi_change_reason, person_update.hbx_member_id, policies_to_notify, cv_change_reason)
      true
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
