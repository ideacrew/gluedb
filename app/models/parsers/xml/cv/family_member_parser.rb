module Parsers::Xml::Cv

  class FamilyMemberParser
    include HappyMapper

    register_namespace "cv", "http://openhbx.org/api/terms/1.0"
    tag 'applicant'
    namespace 'cv'

    element :id, String, tag: "id/cv:id"
    has_one :person, Parsers::Xml::Cv::PersonParser, tag:'person'
    has_many :person_relationships, Parsers::Xml::Cv::PersonRelationshipParser, xpath:'cv:person_relationships'
    has_one :person_demographics, Parsers::Xml::Cv::PersonDemographicsParser, tag:'person_demographics'
    has_many :alias_ids, String, xpath: 'cv:id/cv:alias_ids/cv:alias_id/cv:id'
    element :is_primary_applicant, String, tag: 'is_primary_applicant'
    element :tax_household_id, String, tag: 'tax_household_id'
    element :is_coverage_applicant, String, tag: 'is_coverage_applicant'
    has_many :financial_statements, Parsers::Xml::Cv::FinancialStatementParser, xpath:'cv:financial_statements'
    element :is_active, String, tag: 'is_active'
    has_many :employee_family_members, Parsers::Xml::Cv::EmployeeFamilyMemberParser, xpath:'cv:employee_applicants'
    element :is_consent_applicant, String, tag: 'is_consent_applicant'

    def to_individual_request(member_id_generator, p_tracker)
      alias_ids.each do |a_id|
        p_tracker.register_alias(a_id,id)
      end
      person.individual_request(member_id_generator).merge(person_demographics.individual_request).merge({
        :emails => email_requests,
        :addresses => address_requests,
        :phones => phone_requests
      })
    end

    def dob
      Date.parse(person_demographics.birth_date)
    end

    def age
      Ager.new(dob).age_as_of(Date.parse("2015-1-1"))
    end

    def address_requests
      person.address_requests
    end

    def email_requests
      person.email_requests
    end

    def phone_requests
      person.phone_requests
    end

    def to_relationships
      person_relationships.map do |person_relationships|
        person_relationships.to_relationship
      end
    end

    def to_hash(p_tracker=nil)
     response = {
         family_member_id: id,
         is_primary_applicant: is_primary_applicant,
         is_coverage_applicant: is_coverage_applicant,
         person_demographics: person_demographics.to_hash,
         financial_statements: financial_statements.map(&:to_hash),
         employee_family_members: employee_family_members.map(&:to_hash),
         is_consent_applicant: is_consent_applicant,
         alias_ids: alias_ids
     }

     response[:person] = p_tracker[id].first if p_tracker

     response
    end

    def income_by_year(year)
      total_income = 0.0
      financial_statements.select do |financial_statement|
        incomes = financial_statement.to_hash[:incomes]
        incomes = incomes.select{|income| income[:total_income_by_year] == calendar_year }
        incomes.each {|x| total_income += x[:income].to_f }
      end
      sprintf("%.2f", total_income)
    end
  end
end
