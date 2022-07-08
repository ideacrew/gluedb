module ExternalEvents
  class ExternalPolicyReinstate
    attr_reader :policy_node
    attr_reader :existing_policy

    include Handlers::EnrollmentEventXmlHelper

    # p_node : Openhbx::Cv2::Policy
    # existing_policy : Policy
    def initialize(p_node, existing_policy)
      @policy_node = p_node
      @existing_policy = existing_policy
    end

    def extract_pre_amt_tot
      p_enrollment = Maybe.new(@policy_node).policy_enrollment.value
      return 0.00 if p_enrollment.blank?
      BigDecimal.new(Maybe.new(p_enrollment).premium_total_amount.strip.value)
    end

    def extract_tot_res_amt
      p_enrollment = Maybe.new(@policy_node).policy_enrollment.value
      return 0.00 if p_enrollment.blank?
      BigDecimal.new(Maybe.new(p_enrollment).total_responsible_amount.strip.value)
    end

    def extract_aptc_value
      p_enrollment = Maybe.new(@policy_node).policy_enrollment.value
      return 0.00 if p_enrollment.blank?
      applied_aptc_val = Maybe.new(p_enrollment).individual_market.applied_aptc_amount.strip.value
      return 0.00 if applied_aptc_val.blank?
      BigDecimal.new(applied_aptc_val)
    end

    def is_shop?
      p_enrollment = Maybe.new(@policy_node).policy_enrollment.value
      return false if p_enrollment.blank?
      p_enrollment.shop_market
    end

    def subscriber_start
      sub_node = extract_subscriber(@policy_node)
      extract_enrollee_start(sub_node)
    end

    def build_aptc_credits(policy)
      unless is_shop?
        new_aptc_date = subscriber_start
        policy.set_aptc_effective_on(new_aptc_date, extract_aptc_value, extract_pre_amt_tot, extract_tot_res_amt)
        policy.save!
      end
    end

    def update_policy_information
      @existing_policy.update_attributes!({
        :aasm_state => "resubmitted",
        term_for_np: false
      })
      @existing_policy.hbx_enrollment_ids << extract_enrollment_group_id(@policy_node)
      result = @existing_policy.save!

      build_aptc_credits(@existing_policy)

      Observers::PolicyUpdated.notify(@existing_policy)
      result
    end

    def update_enrollee(enrollee_node)
      member_id = extract_member_id(enrollee_node)
      enrollee = @existing_policy.enrollees.detect { |en| en.m_id == member_id }
      if enrollee
        enrollee.ben_stat = "active"
        enrollee.emp_stat = "active"
        enrollee.coverage_end = nil
        enrollee.termed_by_carrier = false
        enrollee.save!
      end
      @existing_policy.save!
    end

    def persist
      @policy_node.enrollees.each do |en|
        update_enrollee(en)
      end
      update_policy_information
      true
    end
  end
end
