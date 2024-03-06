require 'nokogiri'

class XmlValidator

  attr_accessor :folder_path

  def validate(filename=nil, type: :h36)
    Dir.foreach("#{@folder_path}/transmission") do |filename|
      next if filename == '.' or filename == '..' or filename == 'manifest.xml' or filename == '.DS_Store'

      puts "processing...#{filename.inspect}"
      if type == :h41
        # xsd = Nokogiri::XML::Schema(File.open("#{Rails.root.to_s}/ACA_AIR5_1095-ASchema-Marketplace/MSG/IRS-Form1095ATransmissionUpstreamMessage.xsd")) #IRS ty2018
        path = "#{Rails.root}/IEP_AIR_5_0_1095A_FS21_Upstream_schema_package_v1_0_06222020/MSG/IRS-Form1095ATransmissionUpstreamMessage.xsd" #IRS ty2020
        xsd = Nokogiri::XML::Schema(File.open(path))
      end

      if type == :h36
        # xsd = Nokogiri::XML::Schema(File.open("#{Rails.root.to_s}/XML_LIBRARY_8_18/MSG/HHS-IRS-MonthlyExchangePeriodicDataMessage-1.0.xsd")) # IRS 2016
        xsd = Nokogiri::XML::Schema(File.open("#{Rails.root.to_s}/HHS_ACA_XML_LIBRARY_10.1/MSG/HHS-IRS-MonthlyExchangePeriodicDataMessage-1.0.xsd")) # IRS 2018
      end

      doc = Nokogiri::XML(File.open("#{@folder_path}/transmission/" + filename))

      xsd.validate(doc).each do |error|
        puts error.message
      end
    end
  end
end
