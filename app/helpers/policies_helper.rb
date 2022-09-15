module PoliciesHelper

  def show_1095A_document_button?(policy)
    if policy.subscriber
      Time.now.in_time_zone('Eastern Time (US & Canada)').year > policy.subscriber.coverage_start.year
    else
      false
    end
  end

  def disable_radio_button?(policy)
    ["canceled", "carrier_canceled"].include? policy.aasm_state
  end

  def as_dollars(val)
    BigDecimal.new(val.to_s).round(2)
  end

  #osse calculation
  def osse_amt(policy)
    total_premium_amount = policy.pre_amt_tot.to_f
    total_responsible_amount = policy.tot_res_amt.to_f
    employer_contribution = policy.tot_emp_res_amt.to_f
    aptc_amount = policy.applied_aptc.to_f
    if policy.employer_id.present?
      as_dollars(total_premium_amount - employer_contribution - total_responsible_amount).to_f
    else
      as_dollars(total_premium_amount - aptc_amount - total_responsible_amount).to_f
    end
  end
end
