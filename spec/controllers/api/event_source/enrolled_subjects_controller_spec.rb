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

    describe "given a valid hios_id and year, but no results" do
      let(:the_hios_id) { "A VALID HIOS ID" }
      let(:the_year) { "2015" }

      before :each do
        allow(SubscriberInventory).to receive(:subscriber_ids_for).with(
          the_hios_id,
          the_year.to_i
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
      let(:the_year) { "2015" }
      let(:matching_subscriber_id) { "A SUBSCRIBER ID" }

      before :each do
        allow(SubscriberInventory).to receive(:subscriber_ids_for).with(
          the_hios_id,
          the_year.to_i
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

  describe "GET :show, when not authenticated" do
    it "redirects to ask for login" do
      get :show, { :id => "a bogus id" }
      expect(response).to have_http_status(302)
    end
  end

  describe "GET :show, when authenticated" do
    let(:user_token) { "A USER TOKEN" }
    let(:user) { User.new(:approved => true) }

    before :each do
      allow(User).to receive(:find_by_authentication_token).with(
        user_token
      ).and_return(user)
    end

    describe "with a member that doesn't exist" do
      it "returns 404" do
        get :show, { :id => "a bogus id", :user_token => user_token }
        expect(response).to have_http_status(404)
      end
    end

    describe "with a member that exists" do
      before :each do
        allow(Person).to receive(:find_for_member_id).with("a member id").and_return(
          person
        )
        allow(SubscriberInventory).to receive(:coverage_inventory_for).with(
          person
        ).and_return({})
      end

      let(:person) { instance_double(Person) }

      it "returns the coverage history for that member" do
        get :show, { :id => "a member id", :user_token => user_token }
        expect(response).to have_http_status(200)
        expect(response.body).to eq("{}")
      end
    end
  end
end
