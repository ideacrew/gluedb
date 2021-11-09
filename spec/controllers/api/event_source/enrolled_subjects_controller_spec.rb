require "rails_helper"

describe Api::EventSource::EnrolledSubjectsController do
  describe "GET index, when not authenticated" do
    it "redirects to ask for login" do
      get :index
      expect(response).to have_http_status(302)
    end
  end

  describe "GET index, when authenticated" do
    let(:user_token) { "A USER TOKEN" }
    let(:user) { User.new(:approved => true) }

    before :each do
      allow(User).to receive(:find_by_authentication_token).with(
        user_token
      ).and_return(user)
    end

    describe "given no parameters" do
      it "returns 422" do
        get :index, {user_token: user_token}
        expect(response).to have_http_status(422)
      end
    end

    describe "given a non-existant hios_id and year" do
      let(:the_hios_id) { "SOME BOGUS HIOS ID" }
      let(:the_year) { "SOME BOGUS YEAR" }

      it "returns 404" do
        get :index, {year: the_year, hios_id: the_hios_id, user_token: user_token}
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "given a valid hios_id and year, but no results" do
      let(:the_hios_id) { "A VALID HIOS ID" }
      let(:the_year) { "A VALID YEAR" }

      before :each do
        allow(Plan).to receive(:find_by_hios_id_and_year).with(
          the_hios_id,
          the_year.to_i
        ).and_return(plan)
        allow(SubscriberInventory).to receive(:subscriber_ids_for).with(
          plan
        ).and_return([])
      end

      let(:plan) do
        instance_double(Plan)
      end

      it "returns 200 and the empty list" do
        get :index, {year: the_year, hios_id: the_hios_id, user_token: user_token}
        expect(response).to have_http_status(:ok)
        expect(response.body).to eq([].to_json)
      end
    end

    describe "given a valid hios_id and year, and enrolled subscribers" do
      let(:the_hios_id) { "A VALID HIOS ID" }
      let(:the_year) { "A VALID YEAR" }
      let(:matching_subscriber_id) { "A SUBSCRIBER ID" }

      before :each do
        allow(Plan).to receive(:find_by_hios_id_and_year).with(
          the_hios_id,
          the_year.to_i
        ).and_return(plan)
        allow(SubscriberInventory).to receive(:subscriber_ids_for).with(
          plan
        ).and_return([matching_subscriber_id])
      end

      let(:plan) do
        instance_double(Plan)
      end

      it "returns 200 and the subscriber list" do
        get :index, {year: the_year, hios_id: the_hios_id, user_token: user_token}
        expect(response).to have_http_status(:ok)
        expect(response.body).to eq([matching_subscriber_id].to_json)
      end
    end
  end
end
