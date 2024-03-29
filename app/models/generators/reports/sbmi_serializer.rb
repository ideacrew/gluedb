require 'spreadsheet'
require 'csv'
module Generators::Reports
  # This class generates the CMS policy based payments (PBP), SBMI file
  class SbmiSerializer
    # To generate irs yearly policies need to send a run time calendar_year params i.e. Generators::Reports::SbmiSerializer.new({calendar_year: 2021}) instead sending hard coded year
    # CANCELED_DATE = Date.new(2017,12,8)

    attr_accessor :pbp_final, :settings, :calendar_year, :hios_prefix_ids, :subdirectory_prefix

    def initialize(options = {})
      @sbmi_root_folder = "#{Rails.root}/sbmi"
      @settings = YAML.load(File.read("#{Rails.root}/config/irs_settings.yml")).with_indifferent_access
      @calendar_year = options[:calendar_year]
      @hios_prefix_ids = @settings[:cms_pbp_generation][:hios_prefix_ids]
      @subdirectory_prefix = @settings[:cms_pbp_generation][:subdirectory_prefix]
      # @sbmi_folder_name = "DCHBX_SBMI_78079_17_00_01_06_2017"

      create_directory @sbmi_root_folder
    end

    def process
      #%w(86052 78079 94506 81334 92479 95051).each do |hios_prefix|  (DCHBX hios_prefix)
      hios_prefix_ids.each do |hios_prefix|
        plan_ids = Plan.where(hios_plan_id: /^#{hios_prefix}/, year: calendar_year).pluck(:_id)
        puts "Processing #{hios_prefix}"

        # workbook = Spreadsheet::Workbook.new
        # sheet = workbook.create_worksheet :name => "#{calendar_year} SBMI Report"

        # index = 0
        # sheet.row(index).concat headers

        create_sbmi_folder(hios_prefix)

        count = 0
        Policy.where(:plan_id.in => plan_ids).no_timeout.each do |pol|
          begin
            next if pol.is_shop? # || pol.rejected? || pol.has_responsible_person?

            # * re-enable for post first report in a calendar year
            # if pol.canceled?
            #   next if pol.updated_at < Date.new(calendar_year,5,1)
            # else
            #   next if pol.has_no_enrollees?
            # end

            # disbale for post first report in a calendar year
            # next if pol.canceled? && pol.updated_at < CANCELED_DATE

            # next if pol.canceled?
            # next if pol.has_no_enrollees?
            next if pol.policy_start < Date.new(calendar_year, 1, 1)
            next if pol.policy_start > Date.new(calendar_year, 12, 31)

            if pol.subscriber.person.blank?
              puts "subscriber person record missing #{pol.id}"
              next
            end

            if !pol.belong_to_authority_member?
              puts "skipping non authority member policy #{pol.id} #{pol.eg_id}"
              next
            end

            if policies_to_skip.include?(pol.id.to_s)
              puts "skipping policies_to_skip policy #{pol.id} #{pol.eg_id}"
              next
            end

            if pol.kind == 'coverall'
              puts "skipping coverall policy #{pol.id} #{pol.eg_id}"
              next
            end

            count +=1
            if count % 100 == 0
              puts "processing #{count}"
            end

            begin
              builder = Generators::Reports::SbmiPolicyBuilder.new(pol)
              builder.process
            rescue Exception => e
              puts "Exception: #{pol.id}"
              puts e.inspect
              next
            end

            sbmi_xml = SbmiXml.new
            sbmi_xml.sbmi_policy = builder.sbmi_policy
            sbmi_xml.folder_path = "#{@sbmi_root_folder}/#{@sbmi_folder_name}"
            sbmi_xml.serialize

            # index += 1
            # sheet.row(index).concat builder.sbmi_policy.to_csv
          rescue Exception => e
            puts "Exception: #{pol.id}"
            puts e.inspect
            next
          end
        end

        merge_and_validate_xmls(hios_prefix)

        # workbook.write "#{Rails.root.to_s}/#{calendar_year}_SBMI_DATA_EXPORT_#{Time.now.strftime("%Y_%m_%d_%H_%M")}_#{hios_prefix}.xls"
      end
    end

     def merge_and_validate_xmls(hios_prefix)
      xml_merge = Generators::Reports::SbmiXmlMerger.new("#{@sbmi_root_folder}/#{@sbmi_folder_name}")
      xml_merge.sbmi_folder_path = @sbmi_root_folder
      xml_merge.hios_prefix = hios_prefix
      xml_merge.calendar_year = calendar_year
      xml_merge.process
      xml_merge.validate
    end

    # def self.generate_sbmi(listener, coverage_year, pbp_final)
    #   calendar_year = coverage_year.to_i

    #   begin
    #     set_cancel_date
    #     sbmi_serializer = Generators::Reports::SbmiSerializer.new
    #     sbmi_serializer.pbp_final = pbp_final
    #     sbmi_serializer.process
    #     return "200"
    #   rescue Exception => e
    #     return "500"
    #   end
    # end

    # def set_cancel_date
    #   prev_month = Date.today.prev_month.beginning_of_month

    #   if Date.today.day == 1
    #     CANCELED_DATE = Date.new(prev_month.year, prev_month.month, 10)
    #   else
    #     CANCELED_DATE = Date.new(Date.today.year, Date.today.month, 1)
    #   end
    # end

    private

    def create_sbmi_folder(hios_prefix)
      @sbmi_folder_name = "#{subdirectory_prefix}_SBMI_#{hios_prefix}_#{Time.now.strftime('%H_%M_%d_%m_%Y')}"
      create_directory "#{@sbmi_root_folder}/#{@sbmi_folder_name}"
    end

    def create_directory(path)
      if Dir.exists?(path)
        FileUtils.rm_rf(path)
      end
      Dir.mkdir path
    end

    def financial_headers
      ['Financial Start', 'Financial End', 'Premium', 'Aptc', 'Responsible Amount', 'Csr Variant'] + 2.times.inject([]) do |cols, i| 
        cols += ["Partial Premium", "Partial Aptc", "Partial Start", 'Partial End']
      end
    end

    def headers
      columns = ['Record Control Number','QHP ID', 'Policy EG ID', 'Subscriber HBXID', 'Policy Start', 'Policy End', 'Coverage Type']
      6.times {|i| columns += ["Covered Member HBX ID", "Is Subscriber", "First Name", "Last Name", "Middle Name","DOB", "SSN", "Gender", "Zipcode", "Member Start", "Member End"]}
      3.times {|i| columns += financial_headers}
      columns
    end

    def policies_to_skip
      ["208128","208671","212304","214429","214807","208674","246907","263444","263496","296902","300021"]
    end
  end
end
