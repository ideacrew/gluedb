require 'rails_helper'

describe EdiTransactionSetsController, :dbclean => :after_each do
  login_user

  describe 'GET errors' do
    let(:eg_id) { '1' }
    let(:range) { (Date.today - 10..Date.today + 10) }
    let!(:carrier) {
      carrier = Carrier.create!
      carrier.carrier_profiles << CarrierProfile.new(fein: "1234")
      carrier
    }
    let!(:another_carrier) {
      carrier = Carrier.create!
      carrier.carrier_profiles << CarrierProfile.new(fein: "56789")
      carrier
    }
    let(:plan) { Plan.create!(:name => "test_plan", :coverage_type => "health") }
    let!(:policy) { Policy.create!(enrollment_group_id: eg_id, carrier_id: carrier.id, plan: plan)}
    let!(:transmission) { Protocols::X12::Transmission.create(isa06: carrier.fein) }
    let!(:transation_set_enrollment) {
      txrn = Protocols::X12::TransactionSetEnrollment.create!(transmission_id: transmission.id, policy: policy.id, submitted_at: range.first, error_list: ["test"], ts_purpose_code: '00', ts_action_code: '2', ts_reference_number: '1', ts_date: '1', ts_time: '1', ts_id: '1', ts_control_number: '1', ts_implementation_convention_reference: '1', transaction_kind: 'initial_enrollment')
      txrn.update_attributes(submitted_at: range.first)
      txrn
    }

    let!(:another_transmission) { Protocols::X12::Transmission.create(isa06: another_carrier.fein) }
    let!(:another_transation_set_enrollment) {
      txrn = Protocols::X12::TransactionSetEnrollment.create!(transmission_id: another_transmission.id, error_list: ["error2"], ts_purpose_code: '00', ts_action_code: '2', ts_reference_number: '1', ts_date: '1', ts_time: '1', ts_id: '1', ts_control_number: '1', ts_implementation_convention_reference: '1', transaction_kind: 'initial_enrollment')
      txrn.update_attributes(submitted_at: range.first - 1.day)
      txrn
    }

    it "renders errors" do
      get :errors, {q: "test"}
      expect(response).to have_http_status(:success)
      expect(response).to render_template :errors

      # search result
      expect(assigns(:transactions).count).to eq(1)
      expect(assigns(:transactions).first.id).to eq(transation_set_enrollment.id)
     end

    it "renders errors page with no results" do
      get :errors, {q: "hello"}
      expect(response).to have_http_status(:success)
      expect(response).to render_template :errors

      # search result
      expect(assigns(:transactions).count).to eq(0)
    end

    it "renders errors page with matched carrier transactions" do
      get :errors, {carrier: carrier.id}
      expect(response).to have_http_status(:success)
      expect(response).to render_template :errors

      # search result
      expect(assigns(:transactions).count).to eq(1)
      expect(assigns(:transactions).first.transmission.ic_sender_id).to eq(carrier.fein)
    end

    it "renders errors page with all matching carrier transactions" do
      get :errors, {carrier: ""}
      expect(response).to have_http_status(:success)
      expect(response).to render_template :errors

      # search result
      expect(assigns(:transactions).count).to eq(2)
      expect(assigns(:transactions).map(&:transmission).map(&:ic_sender_id).sort).to eq(["1234", "56789"])
    end

    it "renders errors page for date range" do
      get :errors, {from_date: range.first.strftime("%m/%d/%Y"), to_date: range.last.strftime("%m/%d/%Y")}
      expect(response).to have_http_status(:success)
      expect(response).to render_template :errors

      # search result
      expect(assigns(:transactions).count).to eq(1)
      expect(range.include?(assigns(:transactions).first.submitted_at)).to eq true
    end

    it "renders errors page with no result for out date range dates" do
      get :errors, {from_date: range.last.strftime("%m/%d/%Y"), to_date: range.last.strftime("%m/%d/%Y")}
      expect(response).to have_http_status(:success)
      expect(response).to render_template :errors

      # search result
      expect(assigns(:transactions).count).to eq(0)
    end

    it "renders errors page with matching policy id" do
      get :errors, {q: eg_id}
      expect(response).to have_http_status(:success)
      expect(response).to render_template :errors

      # search result
      expect(assigns(:transactions).count).to eq(1)
      expect(assigns(:transactions).first.policy.eg_id).to eq(eg_id)
    end

    it "renders errors page with no results when matching policy not found" do
      get :errors, {q: "4444"}
      expect(response).to have_http_status(:success)
      expect(response).to render_template :errors

      # search result
      expect(assigns(:transactions).count).to eq(0)
    end

    it "renders errors page with matching date range,policy id and carrier" do
      get :errors, {from_date: range.first.strftime("%m/%d/%Y"), to_date: range.last.strftime("%m/%d/%Y"), q: eg_id, carrier: carrier.id}
      expect(response).to have_http_status(:success)
      expect(response).to render_template :errors

      # search result
      expect(assigns(:transactions).count).to eq(1)
      expect(range.include?(assigns(:transactions).first.submitted_at)).to eq true # range match
      expect(assigns(:transactions).first.policy.eg_id).to eq(eg_id) # policy match
      expect(assigns(:transactions).first.transmission.ic_sender_id).to eq(carrier.fein) # carrier match
    end

    it "renders errors page with no matching results when out of date range with matching policy id and carrier" do
      get :errors, {from_date: Date.new(2014,1,1).strftime("%m/%d/%Y"), to_date: Date.new(2014,1,1).strftime("%m/%d/%Y"), q: eg_id, carrier: carrier.id}
      expect(response).to have_http_status(:success)
      expect(response).to render_template :errors

      # search result
      expect(assigns(:transactions).count).to eq(0)
    end
  end
end
