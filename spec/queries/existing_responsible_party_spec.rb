require 'rails_helper'

shared_examples "a responsible party query" do
  let(:first_name) { "A first name" }
  let(:last_name) { "A last name" }

  let(:expected_query) {
    {
      "responsible_parties.0" => { "$exists" => true },
      :name_first => Regexp.new(Regexp.escape(first_name), true),
      :name_last => Regexp.new(Regexp.escape(last_name), true)
    }.merge(additional_query_info)
  }

  subject {
    allow(person).to receive(:name_first).and_return(first_name)
    allow(person).to receive(:name_last).and_return(last_name)
    Queries::ExistingResponsibleParty.new(person)
  }

  it "should properly query for an existing responsible party" do
    expect(Person).to receive(:where).with(expected_query).and_return([])
    subject.execute
  end

end

describe Queries::ExistingResponsibleParty, "
given a person with:
- a first name
- last name
- no middle name
" do

  let(:person) {
    double(
      "person",
      :name_middle => "",
      :phones => [],
      :addresses => [],
      :emails => []
    )
  }

  let(:additional_query_info) {
    { "$or" => [] }
  }

  it_should_behave_like "a responsible party query"
end

describe Queries::ExistingResponsibleParty, "
given a person with:
- a first name
- last name
- a middle name
- multiple phones
" do
  let(:middle_name) { "A middle name" }
  let(:phone_type_one) { "home" }
  let(:phone_type_two) { "work" }
  let(:phone_number_one) { "12345" }
  let(:phone_number_two) { "12345" }

  let(:person) {
    phone_one = double("phone1",
                      :phone_type => phone_type_one,
                      :phone_number => phone_number_one
                )
    phone_two = double("phone2",
                      :phone_type => phone_type_two,
                      :phone_number => phone_number_two
                )
    double(
      "person",
      :name_middle => middle_name,
      :phones => [phone_one, phone_two],
      :addresses => [],
      :emails => []
    )
  }

  let(:additional_query_info) {
    {
      :name_middle => Regexp.compile(Regexp.escape(middle_name), true),
      "$or" => [
        {"phones" => { "$elemMatch" => {
          "phone_type" => phone_type_one,
          "phone_number" => phone_number_one
        }}},
        {"phones" => { "$elemMatch" => {
          "phone_type" => phone_type_two,
          "phone_number" => phone_number_two
        }}}
      ]
    }
  }

  it_should_behave_like "a responsible party query"
end

describe Queries::ExistingResponsibleParty, "
given a person with:
- a first name
- last name
- no middle name
- multiple emails
" do
  let(:email_type_one) { "home" }
  let(:email_type_two) { "work" }
  let(:email_address_one) { "12345" }
  let(:email_address_two) { "12345" }

  let(:person) {
    email_one = double("email1",
                      :email_type => email_type_one,
                      :email_address => email_address_one
                )
    email_two = double("email2",
                      :email_type => email_type_two,
                      :email_address => email_address_one
                )
    double(
      "person",
      :name_middle => nil,
      :emails => [email_one, email_two],
      :addresses => [],
      :phones => []
    )
  }

  let(:additional_query_info) {
    {
      "$or" => [
        {"emails" => { "$elemMatch" => {
          "email_type" => email_type_one,
          "email_address" => email_address_one
        }}},
        {"emails" => { "$elemMatch" => {
          "email_type" => email_type_two,
          "email_address" => email_address_two
        }}}
      ]
    }
  }

  it_should_behave_like "a responsible party query"
end

describe Queries::ExistingResponsibleParty, "
given a person with:
- a first name
- last name
- no middle name
- multiple addresses
" do
  let(:address_type_one) { "home" }
  let(:address_type_two) { "work" }
  let(:address_one_street1) { "#1 street" }
  let(:address_one_street2) { "Apt. Whatever" }
  let(:address_one_city) { "City #1" }
  let(:address_one_county_code) { "10010" }
  let(:address_one_state) { "MD" }
  let(:address_one_zip) { "22222" }
  let(:address_two_street1) { "#2 street" }
  let(:address_two_city) { "City #2" }
  let(:address_two_county_code) { "01101" }
  let(:address_two_state) { "DC" }
  let(:address_two_zip) { "22233" }

  let(:person) {
    address_one = double("address1",
                         :address_type => address_type_one,
                         :address_1 => address_one_street1,
                         :address_2 => address_one_street2,
                         :city => address_one_city,
                         :state => address_one_state,
                         :zip => address_one_zip,
                         :location_county_code => address_one_county_code)
    address_two = double("address1",
                         :address_type => address_type_two,
                         :address_1 => address_two_street1,
                         :address_2 => "",
                         :city => address_two_city,
                         :state => address_two_state,
                         :zip => address_two_zip,
                         :location_county_code => address_two_county_code)
    double(
      "person",
      :name_middle => nil,
      :addresses => [address_one, address_two],
      :emails  => [],
      :phones => []
    )
  }

  let(:additional_query_info) {
    {
      "$or" => [
        {"addresses" => { "$elemMatch" => {
          "address_type" => address_type_one,
          "address_1" => address_one_street1,
          "address_2" => address_one_street2,
          "city" => address_one_city,
          "state" => address_one_state,
          "zip" => address_one_zip,
          "location_county_code" => address_one_county_code
        }}},
        {"addresses" => { "$elemMatch" => {
          "address_type" => address_type_two,
          "address_1" => address_two_street1,
          "city" => address_two_city,
          "state" => address_two_state,
          "zip" => address_two_zip,
          "location_county_code" => address_two_county_code
        }}}
      ]
    }
  }

  it_should_behave_like "a responsible party query"
end
