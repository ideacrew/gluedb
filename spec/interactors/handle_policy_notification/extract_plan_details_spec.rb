require "rails_helper"

describe HandlePolicyNotification::ExtractPlanDetails do
  let(:hios_id) { "88889999888833" }
  let(:active_year) { "2017" }
  let(:plan_link){ instance_double(Openhbx::Cv2::PlanLink, :id => hios_id, active_year: active_year)}
  let(:policy_enrollment){ instance_double(Openhbx::Cv2::PolicyEnrollment, plan: plan_link)}
  let(:policy_cv) { instance_double(Openhbx::Cv2::Policy, policy_enrollment: policy_enrollment) }

  let(:interaction_context) {
    OpenStruct.new({
      :policy_cv => policy_cv
    })
  }

  subject { HandlePolicyNotification::ExtractPlanDetails.call(interaction_context) }

  describe "given a policy element" do

    it "should extracts hios_id from plan_link" do
      expect(subject.policy_cv.policy_enrollment.plan.id).to eq hios_id
    end

    it "should extracts active_year from plan_link" do
      expect(subject.policy_cv.policy_enrollment.plan.active_year).to eq active_year
    end

  end

end
