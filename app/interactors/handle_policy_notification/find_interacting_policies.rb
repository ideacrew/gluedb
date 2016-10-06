module HandlePolicyNotification
  class FindInteractingPolicies
    include Interactor

    # Context requires:
    # - policy_details (Openhbx::Cv2::Policy)
    # - plan_details (HandlePolicyNotification::PlanDetails)
    # - member_detail_collection (array of HandlePolicyNotification::MemberDetails)
    # Context outputs:
    # - interacting_policies (array of Policy)
    def call
    end
  end
end