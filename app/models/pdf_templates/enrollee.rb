module PdfTemplates
  class Enrollee
    include Virtus.model

    attribute :name, String
    attribute :ssn, String
    attribute :dob, String
    attribute :subscriber, Boolean, :default => false
    attribute :spouse, Boolean, :default => false
    attribute :coverage_start_date, String
    attribute :coverage_termination_date, String
    attribute :name_first, String
    attribute :name_last, String
    attribute :name_middle, String
    attribute :name_sfx, String
    attribute :hbx_id, String
    attribute :gender, String
    attribute :address, PdfTemplates::NoticeAddress
    attribute :employer, PdfTemplates::EmployerMec


    def coverage_begin
      Date.parse(coverage_start_date)
    end

    def coverage_end
      Date.parse(coverage_termination_date)
    end
  end
end
