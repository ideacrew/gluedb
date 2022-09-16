require "rails_helper"

describe Handlers::EnrollmentEventXmlHelper do
  subject { Class.new { extend Handlers::EnrollmentEventXmlHelper } }

  describe "#extract_subscriber" do
    let(:subscriber) { instance_double(::Openhbx::Cv2::Enrollee, :subscriber? => true) }
    let(:dependent) { instance_double(::Openhbx::Cv2::Enrollee, :subscriber? => false) }

    let(:policy_cv) { instance_double(::Openhbx::Cv2::Policy, :enrollees => [subscriber, dependent]) }

    it "returns the subscriber only" do
      expect(subject.extract_subscriber(policy_cv)).to eq(subscriber)
    end
  end

  describe "#extract_responsible_party_id" do 
    let(:responsible_party) { double(:id => "SOMEGRP#1234") }
    let(:policy_cv) { double(:id => "SOMEGRP#1234", responsible_party: responsible_party ) }
    it "returns the parsed id" do
      expect(subject.extract_responsible_party_id(policy_cv)).to eq("1234")
    end
  end

  describe "#extract_member_id" do
    let(:enrollee) { instance_double(::Openhbx::Cv2::Enrollee, :member => member) }
    let(:member) { instance_double(::Openhbx::Cv2::EnrolleeMember, id: "ABC#54")}

    it "returns the numeric id" do
      expect(subject.extract_member_id(enrollee)).to eq("54")
    end
  end

  describe "#extract_enrollee_start" do
    let(:benefit) { instance_double(::Openhbx::Cv2::EnrolleeBenefit, :begin_date => "20170101") }
    let(:enrollee) { instance_double(::Openhbx::Cv2::Enrollee, :benefit => benefit)}
    it "returns the parsed date" do
      expect(subject.extract_enrollee_start(enrollee)).to eq(Date.new(2017,1,1))
    end
  end

  describe "#extract_enrollee_end" do
    let(:benefit) { instance_double(::Openhbx::Cv2::EnrolleeBenefit, :end_date => "20170101") }
    let(:enrollee) { instance_double(::Openhbx::Cv2::Enrollee, :benefit => benefit)}
    it "returns the parsed date" do
      expect(subject.extract_enrollee_end(enrollee)).to eq(Date.new(2017,1,1))
    end
  end

  describe "#extract_enrollment_group_id" do
    let(:policy_cv) { double(:id => "SOMEGRP#1234") }
    it "returns the parsed id" do
      expect(subject.extract_enrollment_group_id(policy_cv)).to eq("1234")
    end
  end

  describe "#extract_policy_member_ids" do
    let(:subscriber) { instance_double(Member, id: 1) }
    let(:dependent) { instance_double(Member, id: 2) }
    let(:enrollee_sub) { instance_double(::Openhbx::Cv2::Enrollee, :member => subscriber) }
    let(:enrollee_dep) { instance_double(::Openhbx::Cv2::Enrollee, :member => dependent) }
    let(:policy_cv) { double(:enrollees => [enrollee_sub,enrollee_dep]) }

    it "returns the ids" do
      expect(subject.extract_policy_member_ids(policy_cv)).to eq([1,2])
    end
  end

  describe '#extract_employer_link' do
    let(:shop_market) { instance_double(::Openhbx::Cv2::PolicyEnrollmentShopMarket, :employer_link => :employer_link)}
    let(:policy) { instance_double(::Openhbx::Cv2::PolicyEnrollment, :shop_market => shop_market) }
    let(:policy_cv) { double(:policy_enrollment => policy)}

    it "returns the employer link" do
      expect(subject.extract_employer_link(policy_cv)).to eq(:employer_link)
    end
  end

  describe "#find_employer" do
    let(:policy_cv) { double }
    let(:employer_link) { instance_double(::Openhbx::Cv2::EmployerLink, :id => "SOMELINK#VALUE")}
    before do
      allow(subject).to receive(:extract_employer_link).with(policy_cv).and_return(employer_link)
      allow(Employer).to receive(:where).with(hbx_id: 'VALUE').and_return([:employer])
    end

    it "finds the employer" do
      expect(subject.find_employer(policy_cv)).to eq(:employer)
    end
  end

  describe "#find_employer_plan_year" do
    let(:policy_cv) { double }
    let(:employer) { instance_double(Employer) }
    let(:subscriber) { instance_double(::Openhbx::Cv2::Enrollee) }
    before do
      allow(subject).to receive(:find_employer).with(policy_cv).and_return(employer)
      allow(subject).to receive(:extract_subscriber).with(policy_cv).and_return(subscriber)
      allow(subject).to receive(:extract_enrollee_start).with(subscriber).and_return(:start_date)
      allow(employer).to receive(:plan_year_of).with(:start_date).and_return(:start_year)
    end
    it "returns the plan year" do
      expect(subject.find_employer_plan_year(policy_cv)).to eq(:start_year)
    end
  end

  describe "#extract_plan" do
    let(:policy_cv) { double }
    before do
      allow(subject).to receive(:extract_hios_id).with(policy_cv).and_return(:hios_id)
      allow(subject).to receive(:extract_active_year).with(policy_cv).and_return("2016")
      allow(Plan).to receive(:where).with(:hios_plan_id => :hios_id, :year => 2016).and_return([:plan])
    end
    it "extracts the plan" do
      expect(subject.extract_plan(policy_cv)).to eq(:plan)
    end
  end
end

describe Handlers::EnrollmentEventXmlHelper, "#is_osse?" do
  subject { Class.new { extend Handlers::EnrollmentEventXmlHelper } }
  let(:policy_enrollment) do
    instance_double(
      ::Openhbx::Cv2::PolicyEnrollment,
      :premium_credits => premium_credits
    )
  end
  let(:policy_cv) { double(:policy_enrollment => policy_enrollment)}

  describe "given a policy cv with an osse credit" do
    let(:premium_credits) { [aptc_premium_credit, osse_premium_credit] }
    let(:aptc_premium_credit) do
      instance_double(
        ::Openhbx::Cv2::PremiumCredit,
        :kind => "urn:openhbx:terms:v1:premium_credit_kind#aptc",
        :value => "0.00"
      )
    end

    let(:osse_premium_credit) do
      instance_double(
        ::Openhbx::Cv2::PremiumCredit,
        :kind => "urn:dc0:terms:v1:premium_credit_kind#osse",
        :value => "0.00"
      )
    end

    it "is truthy" do
      expect(subject.is_osse?(policy_cv)).to be_truthy
    end
  end

  describe "given a policy cv that has no premium credits" do
    let(:premium_credits) { nil }

    it "#is_osse? is falsey" do
      expect(subject.is_osse?(policy_cv)).to be_falsey
    end
  end

  describe "given a policy cv that has empty premium credits" do
    let(:premium_credits) { [] }

    it "#is_osse? is falsey" do
      expect(subject.is_osse?(policy_cv)).to be_falsey
    end
  end

  describe "given a policy cv that has only aptc premium credits" do
    let(:premium_credits) { [aptc_premium_credit] }
    let(:aptc_premium_credit) do
      instance_double(
        ::Openhbx::Cv2::PremiumCredit,
        :kind => "urn:openhbx:terms:v1:premium_credit_kind#aptc",
        :value => "0.00"
      )
    end

    it "#is_osse? is falsey" do
      expect(subject.is_osse?(policy_cv)).to be_falsey
    end
  end
end