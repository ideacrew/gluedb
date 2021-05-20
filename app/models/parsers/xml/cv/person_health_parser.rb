module Parsers::Xml::Cv
  class PersonHealthParser
    include HappyMapper

    register_namespace "cv", "http://openhbx.org/api/terms/1.0"
    tag 'person_health'
    namespace 'cv'

    element :is_tobacco_user, String,  tag: "person_health/cv:is_tobacco_user"
    element :is_disabled, String, tag: "person_health/cv:is_disabled"

    def to_hash
      {
        tobacco_use: is_tobacco_user
      }

    end
  end
end