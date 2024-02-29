require 'nokogiri'
require 'csv'

module Irs

  class IrsErrors

     XMLNS = {
        "air5.0" => "urn:us:gov:treasury:irs:ext:aca:air:5.0",
        "irs" => "urn:us:gov:treasury:irs:common",
        "batchreq" => "urn:us:gov:treasury:irs:msg:form1095atransmissionupstreammessage",
        "batchresp" => "urn:us:gov:treasury:irs:msg:form1095atransmissionexchrespmessage",
        "reqack" => "urn:us:gov:treasury:irs:msg:form1095atransmissionexchackngmessage",
        "xsi" => "http://www.w3.org/2001/XMLSchema-instance"
    }

    def export_csv
      file_hash = build_file_hash
      policy_ids = []
      file_hash.each do |folder, batch|
        batch.each do |batch_file, sequence_numbers|
          sequence_hash = {}
          Dir.glob("#{Rails.root}/irs_h41/#{folder_name(folder)}/EOY_Request_#{batch_file}*.xml").each do |file_path|
            xml_doc = Nokogiri::XML(File.open(file_path))
            sequence_hash = build_sequence_policy_hash(xml_doc)
          end
          sequence_numbers.each do |number|
            policy_ids << [[folder, batch_file, number[0]].join('|'), number[1], sequence_hash[number[0]]]
          end
        end
      end

      Irs::IrsReportBuilder.new.irs_report_for_errors(policy_ids)
    end

    def folder_name(timestamp)
     year = timestamp.match(/^\d{4}/)[0]
     match_obj = timestamp.to_s.gsub(/^\d{4}/, year[2..3]).match(/(.*)T(.*)/)
     "FEP0020DC.DSH.EOYIN.D#{match_obj[1].gsub('-', '')}.T#{match_obj[2].gsub(':', '').chop}000.P"
   end

    def build_file_hash
      parser = IrsOutputParser.new
      CSV.foreach("#{Rails.root}/irs_output/irs_errors.csv") do |row|
        parser.unique_sequence_num = row[0].strip
        parser.error = row[2].strip
        parser.process
      end
      parser.file_hash
    end

    def build_sequence_policy_hash(xml_doc)
      xml_doc.xpath('//batchreq:Form1095ATransmissionUpstream/air5.0:Form1095AUpstreamDetail', XMLNS).inject({}) do |data, node|
        data[node.at_xpath("air5.0:RecordSequenceNum").content] = node.at_xpath("air5.0:Policy/air5.0:MarketPlacePolicyNum").content.to_i
        data
      end
    end

    def get_policy_ids(xml_doc, sequence_numbers)
      sequence_numbers.inject([]) do |data, seq_num|
        xml_doc.xpath
        data << [seq_num, policy_id]
      end
    end
  end

  class IrsOutputParser

    attr_accessor :unique_sequence_num, :file_hash, :error

    def initialize
      @unique_sequence_num = nil
      @file_hash = {}
      @error = nil
    end

    def process
      if @file_hash[folder_name] && @file_hash[folder_name][batch_seq_num]
        data = @file_hash[folder_name][batch_seq_num]
        data << [ @unique_sequence_num.split("|")[2], @error]
        @file_hash[folder_name][batch_seq_num] = data
      elsif @file_hash[folder_name] && @file_hash[folder_name][batch_seq_num].blank?
        @file_hash[folder_name][batch_seq_num] = [ [ @unique_sequence_num.split("|")[2], @error] ]
      else
        @file_hash[folder_name] = {
          batch_seq_num => [ [ @unique_sequence_num.split("|")[2], @error] ]
        }
      end
    end

    def folder_name
      @unique_sequence_num.split("|")[0]
    end

    def batch_seq_num
      @unique_sequence_num.split("|")[1]
    end
  end
end
