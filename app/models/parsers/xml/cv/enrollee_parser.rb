module Parsers::Xml::Cv

  class EnrolleeParser
    include HappyMapper

    register_namespace "cv", "http://openhbx.org/api/terms/1.0"
    tag 'enrollee'
    namespace 'cv'

    element :is_subscriber, String, tag: "is_subscriber"
    has_one :member, Parsers::Xml::Cv::EnrolleeMemberParser, tag: 'member'
    has_many :person_relationships, Parsers::Xml::Cv::PersonRelationshipParser, xpath:'cv:person_relationships'
    has_one :person_demographics, Parsers::Xml::Cv::PersonDemographicsParser, tag:'person_demographics'
    element :is_primary_applicant, String, tag: 'is_primary_applicant'
    element :is_coverage_applicant, String, tag: 'is_coverage_applicant'

    def to_hash
      result ={
          m_id:member.to_hash[:id],
          is_subscriber:is_subscriber,
          member:member.to_hash,
          person_relationships:person_relationships.map(&:to_hash),
          person_demographics:person_demographics.to_hash,
          tobacco_use:member.to_hash[:person_health]
      }

      result[:is_primary_applicant] = person_demographics if person_demographics
      result[:is_coverage_applicant] = is_coverage_applicant if is_coverage_applicant

      result
    end

  end
end