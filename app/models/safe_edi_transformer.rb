module SafeEdiTransformer
  def safe_transform(xml)
    return xml if xml.nil? || xml.blank?
    if __check_encoding(xml)
      transformed_xml = xml.force_encoding(Encoding::UTF_8)
      EdiSafe.transform(transformed_xml)
    else
      EdiSafe.transform(xml)
    end
  end

  def __check_encoding(string)
    [Encoding::ASCII_8BIT].include?(string.encoding)
  end
end