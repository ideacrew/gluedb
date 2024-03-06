module Generators::Reports  
  class IrsYearlyManifest

    attr_accessor :folder, :calendar_year

    NS = {
      "xmlns"  => "http://birsrep.dsh.cms.gov/exchange/1.0",
      "xmlns:ns3"  => "http://hix.cms.gov/0.1/hix-core", 
      "xmlns:ns4"  => "http://birsrep.dsh.cms.gov/extension/1.0",
      "xmlns:ns5"  => "http://niem.gov/niem/niem-core/2.0"
      # "xmlns:inp1" => "http://xmlns.oracle.com/singleString", 
      # "xmlns:wsa"  => "http://www.w3.org/2005/08/addressing"      
    }

    def create(folder, calendar_year)
      @calendar_year = calendar_year
      @folder = folder
      @manifest = OpenStruct.new({
        file_count: Dir.glob(@folder+'/*.xml').count,
      })
      manifest_xml = serialize.to_xml(:indent => 2)
      File.open("#{folder}/manifest.xml", 'w') do |file|
        file.write manifest_xml
      end
    end

    def serialize
      Nokogiri::XML::Builder.new { |xml|
        xml.BatchHandlingServiceRequest(NS) do |xml|
          serialize_batch_data(xml)
          serialize_transmission_data(xml)
          serialize_service_data(xml)
          attachments.each do |attachment|
            serialize_attachment(xml, attachment)
          end
        end
      }
    end

    def attachments
      Dir.glob(@folder+'/*.xml').inject([]) do |data, file|
        data << OpenStruct.new({
          checksum: Digest::SHA256.file(file).hexdigest,
          binarysize: File.size(file),
          filename: File.basename(file),
          sequence_id: File.basename(file).match(/\d{5}/)[0]
        })
      end
    end

    def serialize_batch_data(xml)
      xml['ns3'].BatchMetadata do |xml|
        xml['ns3'].BatchID Time.now.utc.iso8601
        xml['ns3'].BatchPartnerID '02.DC*.SBE.001.001'
        xml['ns3'].BatchAttachmentTotalQuantity @manifest.file_count
        xml['ns4'].BatchCategoryCode 'IRS_EOY_REQ'
        xml['ns3'].BatchTransmissionQuantity 1
      end
    end

    def serialize_transmission_data(xml)
      xml['ns3'].TransmissionMetadata do |xml|
        xml['ns3'].TransmissionAttachmentQuantity @manifest.file_count
        xml['ns3'].TransmissionSequenceID 1
      end
    end

    def serialize_service_data(xml)
      xml['ns4'].ServiceSpecificData do |xml|
        xml['ns4'].ReportPeriod do |xml|
          xml['ns5'].Year calendar_year
        end
      end
    end

    def serialize_attachment(xml, file)
      xml['ns4'].Attachment do |xml|
        xml['ns5'].DocumentBinary do |xml|
          xml['ns3'].ChecksumAugmentation do |xml|
            xml['ns4'].SHA256HashValueText file.checksum
          end
          xml['ns3'].BinarySizeValue file.binarysize
        end
        xml['ns5'].DocumentFileName file.filename
        xml['ns5'].DocumentSequenceID file.sequence_id
      end
    end
  end
end
