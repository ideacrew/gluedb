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
end
