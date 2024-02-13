module Generators::Reports  
  class IrsHousehold

    attr_accessor :calendar_year, :tax_households, :tax_household_objs

    def initialize(household)
      @household = household
      @calendar_year = nil
      @tax_households = []
      @tax_household_objs = []
      @taxhouseholds_policies = {}
    end

    def process
      @tax_households = @household.tax_households
      # puts @tax_households.flat_map(&:tax_household_members).map{|x| x.tax_filing_status}.inspect
      if @household.tax_households.count > 1
        # Remove duplicates by picking the second tax household
        tax_households_hash = @household.tax_households.inject({}) do |tax_households, tax_household|
          member_hash = tax_household.tax_household_members.inject({}) do |members_with_financials, member|
            members_with_financials[member.family_member_id] = member.tax_filing_status
            members_with_financials
          end
          tax_households.delete_if{|key,val| val == member_hash}
          tax_households[tax_household] = member_hash
          tax_households
        end
        @tax_households = tax_households_hash.keys
      end

      @taxhouseholds_policies = build_taxhouseholds_policies
      build_irs_tax_households
    end

    def build_taxhouseholds_policies
      enrollments = @household.enrollments_for_year(@calendar_year)
      enrollments.inject({}) do |hash, enrollment|
        tax_household = select_tax_household(enrollment)
        if tax_household
          (hash[tax_household.id] ||= []) << enrollment.policy_id
        end
        hash
      end
    end

    def select_tax_household(enrollment)
      subscriber = enrollment.policy.subscriber.person
      tax_household = @tax_households.detect{|tax_household| is_tax_filer?(tax_household, subscriber)}
      if tax_household.nil?
        tax_household = @tax_households.detect{|tax_household| is_member?(tax_household, subscriber)}
      end
      raise 'no tax_household to attach' if tax_household.nil?
      tax_household
    end

    def build_irs_tax_households
      @tax_households.each do |tax_household|
        irs_taxhousehold = Generators::Reports::IrsTaxHousehold.new(tax_household, @taxhouseholds_policies[tax_household.id])
        irs_taxhousehold.build
        raise "No Primary!!" if irs_taxhousehold.primary.blank?
        @tax_household_objs << irs_taxhousehold
      end
    end

    def is_tax_filer?(tax_household, person)
      tax_household.tax_household_members.select{ |member|
        member.tax_filing_status == 'tax_filer'
      }.detect{|member|
        member.family_member.person == person
      }.nil? ? false : true
    end

    def is_member?(tax_household, person)
      tax_household.tax_household_members.select{ |member|
        member.tax_filing_status != 'tax_filer'
      }.detect{|member|
        member.family_member.person == person
      }.nil? ? false : true
    end
  end
end