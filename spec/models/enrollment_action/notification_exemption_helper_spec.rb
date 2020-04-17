require "rails_helper"

describe EnrollmentAction::NotificationExemptionHelper, :dbclean => :after_each do
  subject { Class.new { extend EnrollmentAction::NotificationExemptionHelper } }

  describe "termination_event_exempt_from_notification?" do
    let(:current_year) { ((today.beginning_of_year)..today.end_of_year) }
    let!(:termination_date1) {"12/31/2019"}
    let!(:termination_date2) {"12-31-2019"}
    let!(:termination_date3) {"10/31/2019"}
    let!(:termination_date4) {"10-31-2019"}

    context "given a shop policy" do
      let(:policy) do
        instance_double(
          Policy,
          is_shop?: true,
          kind: 'employer_sponsored'
        )
      end

      it "returns false when policy is a shop" do
        expect(subject.termination_event_exempt_from_notification?(policy, termination_date1)).to be_false
      end
    end

    context "given a IVL policy" do
      let(:policy) do
        instance_double(
          Policy,
          is_shop?: false,
          kind: 'individual',
          coverage_type: "health"
        )
      end

      it "return true when termination date is sent i.e 12/31/2019(%m/%d/%Y)" do
        expect(subject.termination_event_exempt_from_notification?(policy, termination_date1)).to be_truthy
      end

      it "return false when termination date is sent i.e 10/31/2019(%m/%d/%Y)" do
        expect(subject.termination_event_exempt_from_notification?(policy, termination_date3)).to be_false
      end

      it "return true when termination date is sent i.e 12-31-2019(%m-%d-%Y)" do
        expect(subject.termination_event_exempt_from_notification?(policy, termination_date2)).to be_truthy
      end

      it "return false when termination date is sent i.e 10-31-2019(%m-%d-%Y)" do
        expect(subject.termination_event_exempt_from_notification?(policy, termination_date4)).to be_false
      end
    end
  end
end