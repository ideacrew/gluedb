module RemoteResources
  class IndividualResource
    include HappyMapper

    register_namespace "cv", "http://openhbx.org/api/terms/1.0"
    tag 'individual'
    namespace 'cv'

    element :id, String, tag: "id/cv:id"

    has_one :person, ::RemoteResources::Person, :tag => "person"
    has_one :person_demographics, ::RemoteResources::PersonDemographics, :tag => "person_demographics"
    has_many :relationships, ::RemoteResources::PersonRelationship,  :tag => "person_relationship"


    delegate :name_first, :name_last, :name_middle, :name_sfx, :name_pfx, :addresses, :emails, :phones, :to => :person, :allow_nil => true

    delegate :ssn, :dob, :gender, :to => :person_demographics, :allow_nil => true

    def hbx_member_id
      Maybe.new(id).strip.split("#").last.value
    end

    def exists?
      !record.nil?
    end

    def inspect
      main_hash = to_hash
      members_too = main_hash.merge(member_hash)
      members_too[:addresses] = addresses.map(&:to_hash)
      members_too[:emails] = emails.map(&:to_hash)
      members_too[:phones] = phones.map(&:to_hash)
      members_too.inspect
    end

    def to_s
      inspect
    end

    def to_hash
      props_hash = {
        :name_first => name_first,
        :name_last => name_last
      }
      if !name_middle.blank?
        props_hash[:name_middle] = name_middle
      end
      if !name_pfx.blank?
        props_hash[:name_pfx] = name_pfx
      end
      if !name_sfx.blank?
        props_hash[:name_sfx] = name_sfx
      end
      props_hash
    end

    def member_hash
      props_hash = {
        :hbx_member_id => hbx_member_id
      }
      if !dob.blank?
        props_hash[:dob] = dob
      end
      if !gender.blank?
        props_hash[:gender] = gender
      end
      if !ssn.blank?
        props_hash[:ssn] = ssn
      end
      props_hash
    end

    def record
      @record ||= ::Queries::PersonByHbxIdQuery.new(hbx_member_id).execute
    end

    def self.retrieve(requestable, individual_id)
      di, rprops, resp_body = [nil, nil, nil]
      begin
        di, rprops, resp_body = requestable.request({:headers => {:individual_id => individual_id.to_s}, :routing_key => "resource.individual"},"", 30)
        r_headers = (rprops.headers || {}).to_hash.stringify_keys
        r_code = r_headers['return_status'].to_s
        if r_code == "200"
          [r_code, self.parse(resp_body, :single => true)]
        else
          [r_code, resp_body.to_s]
        end
      rescue Timeout::Error => e
        ["503", ""]
      end
    end
  end
end
