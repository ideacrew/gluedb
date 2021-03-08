require 'rails_helper'

describe PoliciesController, :dbclean => :after_each do

  let(:policy) { FactoryGirl.create(:policy) }
  let(:person) { FactoryGirl.create(:person) }

  before(:each) do
    allow(controller).to receive(:generate_1095A_pdf).and_return("")
    @user = create :user, :admin
    sign_in @user
  end

  describe 'POST generate_tax_document' do

    context "no preview" do
      context "success" do
        before do
          post :generate_tax_document, {person_id: person.id, id: policy.id}.merge(
              {"type" => "original", "void_policy_ids" => "", "npt" => "1", "preview" => "0"})
        end

        it 'redirects to `person_path`' do
          expect(response).to redirect_to(person_path(person))
        end
      end

      context "failure" do
        before do
          allow(controller).to receive(:upload_to_s3).with(an_instance_of(String), an_instance_of(String)).and_return(false)
          post :generate_tax_document, {person_id: person.id, id: policy.id}.merge(
              {"type" => "original", "void_policy_ids" => "", "npt" => "1", "preview" => "0"})
        end

        it 'redirects to `person_path` with status code 500' do
          expect(flash[:error]).to match(/Could not upload file/)
        end
      end
    end

    context "preview" do
      before do
        post :generate_tax_document, {person_id: person.id, id: policy.id}.merge(
            {"type" => "original", "void_policy_ids" => "", "npt" => "1", "preview" => "1"})
      end

      it 'renders `generate_tax_document` template' do
        expect(response).to render_template("generate_tax_document")
        expect(response.status).to eq(200)
      end
    end
  end

  describe 'DELETE delete_local_generated_tax_document' do

    context "success" do
      before do
        allow(controller).to receive(:delete_1095A_pdf).with(an_instance_of(String)).and_return(true)
        delete :delete_local_generated_tax_document, {id: policy.id, person_id: person.id, file_name: "file_name.pdf"}
      end

      it 'redirects to `person_path`' do
        expect(response).to redirect_to(person_path(person))
        expect(flash[:notice]).to match(/Deleted the generated 1095A PDF/)
      end
    end

    context "failure" do
      before do
        allow(controller).to receive(:delete_1095A_pdf).with(an_instance_of(String)).and_return(false)
        delete :delete_local_generated_tax_document, {id: policy.id, person_id: person.id, file_name: "file_name.pdf"}
      end

      it 'redirects to `person_path`' do
        expect(response).to redirect_to(person_path(person))
        expect(flash[:error]).to match(/Could not delete 1095A PDF/)
      end
    end
  end

  describe "POST upload_tax_document_to_S3" do

    context "success" do
      let(:file_name) {'file-name.pdf'}
      let(:bucket_name) {'tax-documents'}

      before do
        allow(controller).to receive(:upload_to_s3).with(file_name, bucket_name).and_return(true)
        allow(controller).to receive(:delete_1095A_pdf).with(file_name).and_return(true)
        post :upload_tax_document_to_S3, {id: policy.id, person_id: person.id, file_name: file_name}
      end

      it 'redirects to `person_path`' do
        expect(response).to redirect_to(person_path(person.id))
        expect(flash[:notice]).to match(/1095A PDF queued for upload and storage./)
      end
    end


    context "failure" do
      let(:file_name) {'file-name.pdf'}
      let(:bucket_name) {'tax-documents'}

      before do
        allow(controller).to receive(:upload_to_s3).with(file_name, bucket_name).and_return(false)
        allow(controller).to receive(:delete_1095A_pdf).with(file_name).and_return(true)
        post :upload_tax_document_to_S3, {id: policy.id, person_id: person.id, file_name: file_name}
      end

      it 'redirects to `person_path`' do
        expect(response).to redirect_to(person_path(person.id))
        expect(flash[:error]).to match(/Could not upload file. File upload failed./)
      end

      context "Invalid params: file_name param missing" do
        before do
          post :upload_tax_document_to_S3, {id: policy.id, person_id: person.id}
        end

        it 'fails and redirects to `generate_tax_document_form_policy_path`' do
          expect(response).to redirect_to(generate_tax_document_form_policy_path(policy.id, {person_id: person.id}))
          expect(flash[:error]).to match(/Could not upload document. Request missing essential parameter/)
        end
      end
    end
  end


  describe "Change NPT indicator" do

    let(:mock_event_broadcaster) do
        instance_double(Amqp::EventBroadcaster)
      end
    let(:submitted_by) {"example@example.com"}

    context "Sending True NPT Indicator" do
      before do
        allow(Observers::PolicyUpdated).to receive(:notify).with(policy)
        allow(Amqp::EventBroadcaster).to receive(:with_broadcaster).and_yield(mock_event_broadcaster)
      end

      context "when aasm_state of a policy is in termination state" do
        it "displays success message" do
          policy.update_attributes!(aasm_state: "terminated")
          allow(mock_event_broadcaster).to receive(:broadcast).with(
            {
              :routing_key => "info.events.policy.non_payment_indicator_altered",
              :app_id => "gluedb",
              :headers => {
                "policy_id" =>  policy.id,
                "eg_id" => policy.eg_id,
                "old_npt" => false,
                "new_npt" => true,
                "submitted_by"  => submitted_by
              }
            },
            policy.id
          )
          put :change_npt_indicator, {id: policy.id, policy: {id: policy.id, npt_indicator: "true"}}
          expect(response).to redirect_to(cancelterminate_policy_path(:id => policy.id))
          expect(flash[:notice]).to match(/Successfully updated NPT indicator value/)
        end

        it "displays failure message when policy NPT indicator is already true" do
          policy.update_attributes!(aasm_state: "terminated", term_for_np: true)
          put :change_npt_indicator, {id: policy.id, policy: {id: policy.id, npt_indicator: "true"}}
          expect(flash[:error]).to match(/Failed to update NPT indicator value/)
        end
      end

      context "when aasm_state of a policy is not in termination state" do
        it "displays failure message" do
          put :change_npt_indicator, {id: policy.id, policy: {id: policy.id, npt_indicator: "true"}}
          expect(flash[:error]).to match(/Failed to update NPT indicator value/)
        end
      end
    end

    context "Sending False NPT Indicator" do
      before do
        allow(Observers::PolicyUpdated).to receive(:notify).with(policy)
        allow(Amqp::EventBroadcaster).to receive(:with_broadcaster).and_yield(mock_event_broadcaster)
      end

      context "when aasm_state of a policy is in termination state" do
        it "displays success message" do
          policy.update_attributes!(aasm_state: "terminated", term_for_np: true)
          allow(mock_event_broadcaster).to receive(:broadcast).with(
            {
              :routing_key => "info.events.policy.non_payment_indicator_altered",
              :app_id => "gluedb",
              :headers => {
                "policy_id" =>  policy.id,
                "eg_id" => policy.eg_id,
                "old_npt" => true,
                "new_npt" => false,
                "submitted_by"  => submitted_by
              }
            },
            policy.id
          )
          put :change_npt_indicator, {id: policy.id, policy: {id: policy.id, npt_indicator: "false"}}
          expect(response).to redirect_to(cancelterminate_policy_path(:id => policy.id))
          expect(flash[:notice]).to match(/Successfully updated NPT indicator value/)
        end
      end

      context "when aasm_state of a policy is not in termination state" do
        it "displays failure message" do
          put :change_npt_indicator, {id: policy.id, policy: {id: policy.id, npt_indicator: "false"}}
          expect(flash[:error]).to match(/Failed to update NPT indicator value/)
        end
      end
    end
  end
end
