module Queries
  class ExistingResponsibleParty
    def initialize(person)
      @person = person
    end

    def execute
      Person.where({
        "responsible_parties.0" => { "$exists" => true }
      }.merge(name_match_expression).merge(additional_match_expressions)).first
    end

    private
    def name_match_expression
      match_expr = {
        :name_first => Regexp.new(Regexp.escape(@person.name_first), true),
        :name_last => Regexp.new(Regexp.escape(@person.name_last), true)
      }
      unless @person.name_middle.blank?
        match_expr[:name_middle] = Regexp.new(Regexp.escape(@person.name_middle), true)
      end
      match_expr
    end

    def additional_match_expressions
      { "$or" => (
        [:phone_match, :email_match, :address_match].inject([]) { |acc, item| method(item).call(acc) }
      )}
    end

    def phone_match(exprs)
      return exprs if @person.phones.empty?
      more_exprs = @person.phones.map do |phone|
        {"phones" => { "$elemMatch" => {"phone_type" => phone.phone_type, "phone_number" => phone.phone_number}}}
      end
      exprs + more_exprs
    end

    def address_match(exprs)
      return exprs if @person.addresses.empty?
      more_exprs = @person.addresses.map do |address|
        address_hash = {
          "address_type" => address.address_type,
          "address_1" => address.address_1,
          "city" => address.city,
          "state" => address.state,
          "zip" => address.zip
        }
        unless address.address_2.blank?
          address_hash["address_2"] = address.address_2
        end
        unless address.location_county_code.blank?
          address_hash["location_county_code"] = address.location_county_code
        end
        {"addresses" => { "$elemMatch" => address_hash}}
      end
      exprs + more_exprs
    end

    def email_match(exprs)
      return exprs if @person.emails.empty?
      more_exprs = @person.emails.map do |email|
        {"emails" => { "$elemMatch" => {"email_type" => email.email_type, "email_address" => email.email_address}}}
      end
      exprs + more_exprs
    end
  end
end
