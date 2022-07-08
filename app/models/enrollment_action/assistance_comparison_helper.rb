module EnrollmentAction
  module AssistanceComparisonHelper
    def aptc_changed?(chunk)
      policy_1 = chunk.first.policy_cv
      policy_2 = chunk.last.policy_cv
      aptc_1 = extract_aptc(policy_1)
      aptc_2 = extract_aptc(policy_2)
      return false if aptc_1.blank?
      return false if aptc_2.blank?
      return true if !(aptc_1 == aptc_2)
      if chunk.first.existing_policy
        return true if chunk.first.existing_policy.applied_aptc != BigDecimal.new(aptc_2)
      end
      false
    end

    def extract_aptc(policy_cv)
      Maybe.new(policy_cv).policy_enrollment.individual_market.applied_aptc_amount.strip.value
    end
  end
end
