 module PdfTemplates
  class TaxHouseholdCoverage
    include Virtus.model

    attribute :calendar_month, Integer
    attribute :primary, PdfTemplates::Enrollee
    attribute :spouse, PdfTemplates::Enrollee
    attribute :dependents, Array[PdfTemplates::Enrollee]
    attribute :policy_ids, Array[Integer]
  end
end