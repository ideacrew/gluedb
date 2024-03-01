module PoliciesHelper

  def show_1095A_document_button?(policy)
    is_policy_not_eligible_to_notify?(policy) ? false : true
  end

  def is_policy_not_eligible_to_notify?(policy)
    policy.kind == 'coverall' || policy.is_shop? || policy.plan.metal_level == "catastrophic" || policy.coverage_type.to_s.downcase != "health" || policy.coverage_year.first.year >= Time.now.year
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
      as_dollars(total_premium_amount - aptc_amount).to_f
    end
  end

  def is_carrier_to_bill?(policy)
    policy.is_osse ? boolean_to_human(false) : boolean_to_human(policy.carrier_to_bill)
  end

  def total_responsible_amount(policy)
    if policy.employer_id.present?
      number_to_currency(policy.tot_res_amt)
    else
      policy.is_osse ? number_to_currency(0.00) : number_to_currency(policy.tot_res_amt)
    end
  end
end
