module Generators::Reports  
  class IrsMonthlyXml
  # To generate irs yearly policies need to send a run time calendar_year params i.e. Generators::Reports::IrsMonthlyXml.new(irs_group, e_case_id, {calendar_year: 2021}) instead of sending hard coded year

    include ActionView::Helpers::NumberHelper

    DURATION = 12

    NS = { 
      "xmlns" => "urn:us:gov:treasury:irs:common",
      "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
      "xmlns:n1" => "urn:us:gov:treasury:irs:msg:monthlyexchangeperiodicdata" # IRS
      # "xmlns:n1" => "urn:us:gov:treasury:irs:msg:sbmpolicylevelenrollment"  # CMS
    }

    attr_accessor :folder_path, :calendar_year

    def initialize(irs_group, e_case_id, options = {})
      @irs_group = irs_group
      @folder_path = folder_path
      @e_case_id = e_case_id
      @settings = YAML.load(File.read("#{Rails.root}/config/irs_settings.yml")).with_indifferent_access
      @calendar_year = options[:calendar_year]
    end
    
    def serialize
      File.open("#{@folder_path}/#{@e_case_id}_#{@irs_group.identification_num}.xml", 'w') do |file|
        file.write builder.to_xml(:indent => 2)
      end
    end

    def builder
      Nokogiri::XML::Builder.new do |xml|
        xml['n1'].HealthExchange(NS) do
          xml.SubmissionYr Date.today.year.to_s
          xml.SubmissionMonthNum Date.today.month.to_s
          xml.ApplicableCoverageYr calendar_year
          xml.IndividualExchange do |xml|
            xml.HealthExchangeId "02.DC*.SBE.001.001"
            serialize_irs_group(xml)
          end
        end
      end
    end

    def serialize_irs_group(xml)
      xml.IRSHouseholdGrp do |xml|
        xml.IRSGroupIdentificationNum @irs_group.identification_num
        serialize_taxhouseholds(xml)
        serialize_insurance_policies(xml)
      end
    end

    def serialize_taxhouseholds(xml)
      @irs_group.irs_households_for_duration(DURATION).each do |tax_household|
        xml.TaxHousehold do |xml|
          (1..DURATION).each do |calendar_month|
            next if @irs_group.irs_household_coverage_as_of(tax_household, calendar_month).empty?
            serialize_taxhousehold_coverage(xml, tax_household, calendar_month)
          end
        end
      end
    end

    def serialize_taxhousehold_coverage(xml, tax_household, calendar_month)
      xml.TaxHouseholdCoverage do |xml|
        xml.ApplicableCoverageMonthNum prepend_zeros(calendar_month.to_s, 2)
        xml.Household do |xml|
          serialize_household_members(xml, tax_household)
          @irs_group.irs_household_coverage_as_of(tax_household, calendar_month).each do |policy|
            montly_disposition = policy.premium_rec_for(calendar_month)
            serialize_associated_policy(xml, montly_disposition, policy)
          end
        end
      end
    end

    def serialize_household_members(xml, tax_household)
      serialize_tax_individual(xml, tax_household.primary, 'Primary')
      serialize_tax_individual(xml, tax_household.spouse, 'Spouse')
      tax_household.dependents.each do |dependent|
        serialize_tax_individual(xml, dependent, 'Dependent')
      end
    end

    def serialize_tax_individual(xml, individual, relation)
      return if individual.blank?
      xml.send("#{relation}Grp") do |xml|
        relation = 'DependentPerson' if relation == 'Dependent'          
        xml.send(relation) do |xml|
          serialize_names(xml, individual)
          xml.SSN individual.ssn unless individual.ssn.blank?
          xml.BirthDt date_formatter(individual.dob)
          serialize_address(xml, individual.address) if relation == 'Primary'
        end
        # individual.employers.each do |employer_url|
        #   serialize_employer(xml, employer)
        # end
      end
    end

    def serialize_names(xml, individual)
      xml.CompletePersonName do |xml|
        xml.PersonFirstName individual.name_first
        xml.PersonMiddleName individual.name_middle
        xml.PersonLastName individual.name_last
        xml.SuffixName individual.name_sfx
      end
    end

    def serialize_address(xml, address)
      xml.PersonAddressGrp do |xml|
        xml.USAddressGrp do |xml|
          xml.AddressLine1Txt address.street_1
          xml.AddressLine2Txt address.street_2
          xml.CityNm address.city.gsub(/[\.\,]/, '')
          xml.USStateCd address.state
          xml.USZIPCd address.zip.split('-')[0]
          # xml.USZIPExtensionCd
        end
      end
    end

    def serialize_associated_policy(xml, montly_disposition, policy)
      slcsp = montly_disposition.premium_amount_slcsp
      slcsp = 0 if slcsp.blank?

      aptc = montly_disposition.monthly_aptc
      aptc = 0 if aptc.blank?
      xml.AssociatedPolicy do |xml|
        xml.QHPPolicyNum policy.policy_id
        xml.QHPIssuerEIN policy.issuer_fein
        xml.SLCSPAdjMonthlyPremiumAmt slcsp
        xml.HouseholdAPTCAmt aptc
        xml.TotalHsldMonthlyPremiumAmt montly_disposition.premium_amount 
      end
    end

    # def serialize_exemptions(xml)
    # end

    # def serialize_exemption_coverage(xml)
    # end

    def serialize_insurance_policies(xml)
      @irs_group.insurance_policies.each do |policy|
        xml.InsurancePolicy do |xml|
          serialize_insurance_coverages(xml, policy)
        end
      end
    end

    def serialize_insurance_coverages(xml, policy)
      policy.monthly_premiums.each do |premium|
        monthly_aptc = premium.monthly_aptc
        monthly_aptc = 0 if monthly_aptc.blank?

        xml.InsuranceCoverage do |xml|
          xml.ApplicableCoverageMonthNum prepend_zeros(premium.serial.to_s, 2)
          xml.QHPPolicyNum policy.policy_id
          # xml.QHPId policy.qhp_id # CMS
          xml.QHPIssuerEIN policy.issuer_fein
          xml.IssuerNm policy.issuer_dc_name
          xml.PolicyCoverageStartDt date_formatter(policy.recipient.coverage_start_date)
          xml.PolicyCoverageEndDt date_formatter(policy.recipient.coverage_termination_date)
          xml.TotalQHPMonthlyPremiumAmt premium.premium_amount
          xml.APTCPaymentAmt monthly_aptc 

          if policy.covered_household_as_of(premium.serial, calendar_year).empty?
            raise "Missing enrollees #{policy.policy_id} #{premium.serial} #{calendar_year}"
          end

          policy.covered_household_as_of(premium.serial, calendar_year).each do |individual|
            serialize_covered_individual(xml, individual)
          end
        end
      end
    end

    def serialize_covered_individual(xml, individual)
      xml.CoveredIndividual do |xml|
        xml.InsuredPerson do |xml|
          serialize_names(xml, individual)
          xml.SSN individual.ssn unless individual.ssn.blank?
          xml.BirthDt date_formatter(individual.dob)
        end
        xml.CoverageStartDt date_formatter(individual.coverage_start_date)
        xml.CoverageEndDt date_formatter(individual.coverage_termination_date)
      end
    end

    private

    def prepend_zeros(number, n)
      (n - number.size).times { number.prepend('0') }
      number
    end

    def date_formatter(date)
      return if date.nil?
      Date.strptime(date,'%m/%d/%Y').strftime("%Y-%m-%d")
    end
  end
end