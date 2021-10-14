require "rails_helper"

shared_examples_for "an address partial" do
    it "has address_line_1" do
      expected_node = subject.at_xpath("//address/address_line_1")
      expect(expected_node.content).to eq address_line_1
    end

    it "has city" do
      expected_node = subject.at_xpath("//address/location_city_name")
      expect(expected_node.content).to eq city
    end

    it "has state" do
      expected_node = subject.at_xpath("//address/location_state_code")
      expect(expected_node.content).to eq state
    end

    it "has zip" do
      expected_node = subject.at_xpath("//address/postal_code")
      expect(expected_node.content).to eq zip
    end
end

describe "people/_address.xml" do
  let(:address_line_1) { "Some first address on a street" }
  let(:state) {"State"}
  let(:zip) {"Zip"}
  let(:city) { "City" }
  let(:render_result) {
    render :partial => "people/address", :formats => [:xml], :object => address
    rendered
  }

  subject {
    Nokogiri::XML(render_result)
  }

  describe "Given:
              - NO address_2 
              - NO address_3
              - NO zip extension" do
    let(:address) { instance_double(Address, {
                                              :address_type => "home",
                                              :address_1 => address_line_1,
                                              :address_2 => nil,
                                              :address_3 => nil,
                                              :city => city,
                                              :state => state,
                                              :zip => zip,
                                              :zip_extension => nil,
                                              :location_county_code => nil
                                            }) }

    it_should_behave_like "an address partial"

    it "has no address_line_2" do
      expected_node = subject.at_xpath("//address/address_line_2")
      expect(expected_node).to eq nil
    end

    it "has no address_line_3" do
      expected_node = subject.at_xpath("//address/address_line_3")
      expect(expected_node).to eq nil
    end

    it "has no zip extension" do
      expected_node = subject.at_xpath("//address/location_postal_extension_code")
      expect(expected_node).to eq nil
    end
  end

  describe "Given:
              - An address_2
              - An address 3
              - A zip extension
              - a county code" do
    let(:address_line_2) { "Some apartment number" }
    let(:address_line_3) { "Some apartment number" }
    let(:zip_extension) { "Some zip extension" }
    let(:county_code) { "0234" }
    let(:address) { instance_double(Address, {
                                              :address_type => "home",
                                              :address_1 => address_line_1,
                                              :address_2 => address_line_2,
                                              :address_3 => address_line_3,
                                              :city => city,
                                              :state => state,
                                              :zip => zip,
                                              :zip_extension => zip_extension,
                                              :location_county_code => county_code
                                            }) }

    it_should_behave_like "an address partial"

    it "has address_line_2" do
      expected_node = subject.at_xpath("//address/address_line_2")
      expect(expected_node.content).to eq address_line_2
    end

    it "has address_line_3" do
      expected_node = subject.at_xpath("//address/address_line_3")
      expect(expected_node.content).to eq address_line_3
    end

    it "has zip_extension" do
      expected_node = subject.at_xpath("//address/location_postal_extension_code")
      expect(expected_node.content).to eq zip_extension
    end

    it "has county code" do
      expected_node = subject.at_xpath("//address/location_county_code")
      expect(expected_node.content).to eq county_code
    end

  end

end
