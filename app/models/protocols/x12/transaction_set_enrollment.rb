class Protocols::X12::TransactionSetEnrollment < Protocols::X12::TransactionSetHeader

  extend Mongorder

	# ASC X12 834 Benefit Enrollment Transaction
  field :bgn01, as: :ts_purpose_code, type: String
  field :bgn02, as: :ts_reference_number, type: String
  field :bgn03, as: :ts_date, type: String
  field :bgn04, as: :ts_time, type: String
  field :bgn05, as: :ts_time_code, type: String, default: "UT"
  field :bgn06, as: :ts_reference_id, type: String
  field :bgn08, as: :ts_action_code, type: String

  field :sponsor_code, as: :loop_1000a_n103, type: String
  field :sponsor_id, as: :loop_1000a_n104, type: String
  field :payer_code, as: :loop_1000b_n103, type: String
  field :payer_id, as: :loop_1000b_n104, type: String

  field :broker_code, as: :loop_1000c_n103, type: String
  field :broker_id, as: :loop_1000c_n104, type: String
  field :tpa_code, as: :loop_1000c_n103_tpa, type: String
  field :tpa_id, as: :loop_1000c_n104_tpa, type: String

  field :maint_type, as: :loop_2000_ins03, type: String
  field :maint_type, as: :loop_2000_ins03, type: String

  field :error_list, type: Array
  field :submitted_at, type: DateTime

  # field :eg_id, as: :enrollment_group_id, String
  index({"bgn01" => 1})
  index({"bgn02" => 1})
  index({"bgn06" => 1})
  index({"bgn08" => 1})
  index({"submitted_at" => 1})
  index({"submitted_at" => 1, "policy_id" => 1})
  index({"policy_id" => 1})

  belongs_to :policy
  belongs_to :employer

  validates_presence_of :ts_purpose_code, :ts_reference_number, :ts_date, :ts_time, :ts_action_code
  validates_inclusion_of :ts_purpose_code, in: ["00", "15", "22"]
  validates_inclusion_of :ts_action_code,  in: ["2", "4", "RX"]

  before_create :parse_submitted_at

  scope :all_change_transactions,  where({:bgn08 =>"2"})
  scope :all_verify_transactions,  where({:bgn08 =>"4"})
  scope :all_replace_transactions, where({:bgn08 =>"RX"})

  def find_for_submitted_date_range(start_date = 1, end_date = 1)

    trans_by_date = Hash.new(0)
    EdiTransactionSet.where(:submitted_at.gte => (Date.today - end_day),
                            :submitted_at.lte => (Date.today - start_day)).each do |ts|
      trans_by_date[ts.submitted_at.strftime("%m-%d")] += 1
    end
    trans_by_date
  end

  class << self
    def submitted_on_count(date)
      where(submitted_at: date.to_time).count
    end

    def default_search_order
      ["submitted_at", -1]
    end

    def search_hash(s_rex)
      search_string = {}
      return search_string if s_rex[:search_string].nil? && s_rex[:carrier].nil?
      if s_rex[:search_string].present?
        search_rex = Regexp.compile(Regexp.escape(s_rex[:search_string]), true)
        policies = Policy.where(Policy.search_hash(s_rex[:search_string]))
        search_string = if policies.present?
                          {:"policy_id".in => policies.map(&:id)}
                        else
                          {"error_list" => search_rex}
                        end
      end
      return search_string unless s_rex[:carrier].present?
      search_string.merge({:"transmission_id".in => Protocols::X12::Transmission.where(ic_sender_id: /#{s_rex[:carrier].fein}/i).map(&:id)})
    end

  end

  protected
    def parse_submitted_at
      self.ts_time = self.ts_time[0..5]
      self.submitted_at = "#{self.ts_date}#{self.ts_time}"
    end
end

