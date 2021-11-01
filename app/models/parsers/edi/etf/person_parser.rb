module Parsers
  module Edi
    module Etf
      class PersonParser
        attr_accessor :address
        def initialize(l2000, emp_id = nil)
          @raw_loop = l2000
          @person_loop = PersonLoop.new(l2000)
          @employer_id = emp_id
        end
        
        def parse_contact
          contact_seg = @raw_loop["L2100A"]["PER"]
          if !contact_seg.blank?
            if contact_seg[3]
              interpret_contact_info(contact_seg[3], contact_seg[4])
            end
            if contact_seg[5]
              interpret_contact_info(contact_seg[5], contact_seg[6])
            end
            if contact_seg[7]
              interpret_contact_info(contact_seg[7], contact_seg[8])
            end
          end
        end

        def interpret_contact_info(con_kind, con_val)
          if con_kind == "TE"
            @phone = con_val
          elsif con_kind == "HP"
            @phone = con_val
          elsif con_kind == "EM"
            @email = con_val
          end
        end

        def persist!
          new_person = check_for_person
          new_member = Member.new

          if @person_loop.gender.blank?
            raise @person_loop.demographic_loop.inspect
          else
            new_member.gender = map_gender_code(@person_loop.gender)
          end

          new_member.hbx_member_id = @person_loop.member_id
          new_member.dob = @person_loop.date_of_birth
          new_member.ssn = @person_loop.ssn
          
          new_member.import_source = "b2b_gateway"
          new_member.imported_at = Time.now

          new_person.name_pfx = @person_loop.name_prefix
          new_person.name_first = @person_loop.name_first
          new_person.name_middle = @person_loop.name_middle
          new_person.name_last = @person_loop.name_last
          new_person.name_sfx = @person_loop.name_suffix
          new_person.merge_member(new_member)

          if !@person_loop.street_lines.blank?
            new_address = Address.new(
                :address_type => "home",
                :address_1 => @person_loop.street1,
                :address_2 => @person_loop.street2,
                :city => @person_loop.city,
                :state => @person_loop.state,
                :zip => @person_loop.zip,
                :location_county_code => @person_loop.county_code
              )
            if new_address.valid?
              new_person.update_address(new_address)
            end
          end

          # Below we've disabled updating emails
          # and phones using EDI as our primary source.
          # This prevents thrashing from the ambiguous
          # way EDI encodes work phones and emails.
          unless @email.blank?
            new_email = Email.new(
              :email_type => "home",
              :email_address => @email.downcase
            )
            #new_person.merge_email(new_email)
            #new_person.update_email(new_email)
          end
          unless @phone.blank?
            new_phone = Phone.new(
              :phone_type => "home",
              :phone_number => @phone
            )
            # new_person.update_phone(new_phone)
          end


          if @person_loop.subscriber?
            if !@employer_id.blank?
              employer = Employer.find(@employer_id)
              employer.employees << new_person
              employer.save
            end
          end
          begin
            new_person.initialize_name_full
            new_person.invalidate_find_caches
            new_person.unsafe_save!
          rescue
            raise(new_person.errors.inspect)
          end
        end

        def parse_employment_status
          @raw_loop["INS"][8]
        end

        def check_for_person
          found_by_m_id_person = Person.find_for_member_id(@person_loop.member_id)
          return(found_by_m_id_person) if !found_by_m_id_person.nil?
          if !@person_loop.ssn.blank?
            found_by_m_ssn_person = Person.match_for_ssn(@person_loop.ssn, @person_loop.name_first, @person_loop.name_last, @person_loop.date_of_birth)
            return(found_by_m_ssn_person) if !found_by_m_ssn_person.nil?
          end
          Person.new
        end

        def self.parse_and_persist(p_loop, employer_id = nil)
          @person_parser = PersonParser.new(p_loop, employer_id)
          @person_parser.parse_all
          @person_parser.persist!
        end

        def parse_all
          parse_contact
        end

        private

        def map_gender_code(code)
          gender_codes = {
            "M" => "male",
            "F" => "female"
          }
          result = gender_codes[code.strip]
          result.nil? ? "unknown" : result
        end
      end
    end
  end
end
