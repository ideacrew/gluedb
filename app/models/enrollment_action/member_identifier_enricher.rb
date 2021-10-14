module EnrollmentAction
  # Utility that adds member identifiers to enrollment event XMLs.
  class MemberIdentifierEnricher
    XML_NS = { :cv => "http://openhbx.org/api/terms/1.0" }

    MEMBER_ID_NS = "urn:openhbx:hbx:me0:resources:v1:person:member_id#"
    POLICY_ID_NS = "urn:openhbx:hbx:me0:resources:v1:person:policy_id#"

    attr_reader :event_xml_doc

    # @param [Object] event_xml_doc the nokogiri doc we want to add stuff to
    def initialize(event_xml_doc)
      @event_xml_doc = event_xml_doc
    end

    def set_carrier_assigned_member_id_for(enrollee)
      if enrollee.c_id
        af_id_node = affected_member_id_node_for(enrollee)
        m_id_node = member_id_node_for(enrollee)
        if af_id_node
          alias_ids_container_node = alias_ids_node_from_id_node(af_id_node)
          id_node_for_am = get_or_build_node_for_urn(alias_ids_container_node, MEMBER_ID_NS)
          id_node_for_am.content = MEMBER_ID_NS + enrollee.c_id
        end
        if m_id_node
          alias_ids_container_node = alias_ids_node_from_id_node(m_id_node)
          id_node_for_member = get_or_build_node_for_urn(alias_ids_container_node, MEMBER_ID_NS)
          id_node_for_member.content = MEMBER_ID_NS + enrollee.c_id
        end
      end
    end

    def set_carrier_assigned_policy_id_for(enrollee)
      if enrollee.cp_id
        af_id_node = affected_member_id_node_for(enrollee)
        m_id_node = member_id_node_for(enrollee)
        if af_id_node
          alias_ids_container_node = alias_ids_node_from_id_node(af_id_node)
          id_node_for_am = get_or_build_node_for_urn(alias_ids_container_node, POLICY_ID_NS)
          id_node_for_am.content = POLICY_ID_NS + enrollee.cp_id
        end
        if m_id_node
          alias_ids_container_node = alias_ids_node_from_id_node(m_id_node)
          id_node_for_member = get_or_build_node_for_urn(alias_ids_container_node, POLICY_ID_NS)
          id_node_for_member.content = POLICY_ID_NS + enrollee.cp_id
        end
      end
    end

    protected

    def get_or_build_node_for_urn(alias_id_node, urn)
      found_alias_node = alias_id_node.at_xpath("cv:alias_id/cv:id[contains(text(), '#{urn}')]", XML_NS)
      return found_alias_node if found_alias_node
      new_node = Nokogiri::XML::Node.new("alias_id", alias_id_node.document)
      new_id_node = Nokogiri::XML::Node.new("id", new_node.document)
      alias_container_node = alias_id_node.add_child(new_node)
      alias_container_node.add_child(new_id_node)
    end

    def alias_ids_node_from_id_node(node)
      base_id_node = node.parent
      alias_ids_node = base_id_node.at_xpath("cv:alias_ids", XML_NS)
      if alias_ids_node.nil?
        new_node = Nokogiri::XML::Node.new("alias_ids", node.document)
        alias_ids_node = node.add_next_sibling(new_node)
      end
      alias_ids_node
    end

    def affected_member_id_node_for(enrollee)
      ids_node = nil
      event_xml_doc.xpath("//cv:enrollment_event_body/cv:affected_members/cv:affected_member/cv:member/cv:id/cv:id", XML_NS).each do |node|
        id_value = Maybe.new(node).text.split("#").last.value
        if id_value == enrollee.m_id
          ids_node = node
          break
        end
      end
      ids_node
    end

    def member_id_node_for(enrollee)
      ids_node = nil
      event_xml_doc.xpath("//cv:enrollment_event_body/cv:enrollment/cv:policy/cv:enrollees/cv:enrollee/cv:member/cv:id/cv:id", XML_NS).each do |node|
        id_value = Maybe.new(node).text.split("#").last.value
        if id_value == enrollee.m_id
          ids_node = node
          break
        end
      end
      ids_node
    end
  end
end