require 'rails_helper'

feature 'uploading a cancel/term CV', :dbclean => :after_each do
  let(:mock_event_broadcaster) do
    instance_double(Amqp::EventBroadcaster)
  end

  let!(:member) { FactoryGirl.build :member, hbx_member_id: '123456' }
  let!(:person) { FactoryGirl.create :person, name_first: 'Example', name_last: 'Person', members: [ member ] }
  let!(:policy1) { Policy.new(eg_id: '1', enrollees: [enrollee1], plan: plan, carrier: carrier, aasm_state: 'resubmitted' ) }
  let!(:policy2) { Policy.new(eg_id: '2', enrollees: [enrollee2], plan: plan, carrier: carrier, employer_id: nil, aasm_state: "terminated", term_for_np: true ) }
  let!(:plan) { build(:plan, id: '5f77432ac09d079fd44c1ae9') }
  let!(:carrier) {create(:carrier, id: '53e67210eb899a4603000004', hbx_carrier_id: '116036')}
  let!(:enrollee1) do
    Enrollee.new(
      m_id: member.hbx_member_id,
      benefit_status_code: 'active',
      employment_status_code: 'active',
      relationship_status_code: 'self',
      coverage_start: Date.new(2020,4,1))
  end
  let!(:enrollee2) do
    Enrollee.new(
      m_id: member.hbx_member_id,
      benefit_status_code: 'active',
      employment_status_code: 'terminated',
      relationship_status_code: 'self',
      coverage_start: Date.new(2020,1,1),
      coverage_end: Date.new(2020,3,31))
  end

  let!(:policy) { Policy.new(eg_id: '7654321', enrollees: [enrollee2], plan: plan, carrier: carrier, employer_id: nil, aasm_state: "terminated", term_for_np: true ) }
  # let(:policy) { FactoryGirl.create(:policy, eg_id: '7654321', aasm_state: 'resubmitted', employer_id: nil, term_for_np: true) }
  given(:premium) do
    PremiumTable.new(
      rate_start_date: Date.new(2020, 1, 1),
      rate_end_date: Date.new(2020, 12, 31),
      age: 53,
      amount: 398.24
    )
  end

  let(:user) { create :user, :admin }

  background do
    visit root_path
    sign_in_with(user.email, user.password)

    # Note: The file fixture is dependent on this record.
    plan = Plan.new(coverage_type: 'health', hios_plan_id: '11111111111111-11', year: 2020, ehb: 0.5)
    plan.premium_tables << premium
    plan.save!

    person.update_attributes!(:authority_member_id => person.members.first.hbx_member_id)
    policy.save!
    policy1.save!
    policy2.save!
    allow(Observers::PolicyUpdated).to receive(:notify).with(policy2)
    allow(Observers::PolicyUpdated).to receive(:notify).with(policy)
  end

  scenario 'nonsubscriber member canceled' do
    file_path = Rails.root + "spec/support/fixtures/cancel/nonsubscriber_cancel.xml"
    allow(Amqp::EventBroadcaster).to receive(:with_broadcaster).and_yield(mock_event_broadcaster)
    allow(mock_event_broadcaster).to receive(:broadcast).with(
      {
        :routing_key => "info.events.legacy_enrollment_vocabulary.uploaded",
        :app_id =>  "gluedb",
        :headers =>  {
          "file_name" => File.basename(file_path),
          "kind" => 'maintenance',
          "submitted_by"  => user.email,
          "bypass_validation" => "false",
          "redmine_ticket" => "1234"
        }
      },
      File.read(file_path)
    )

    visit new_vocab_upload_path

    choose 'Maintenance'
    fill_in "vocab_upload[redmine_ticket]", with: "1234"

    attach_file('vocab_upload_vocab', file_path)

    click_button "Upload"

    expect(page).to have_content 'Uploaded successfully.'
  end

  scenario 'carefirst subscriber member canceled' do
    file_path = Rails.root + "spec/support/fixtures/cancel/carefirst_subscriber_cancel.xml"
    allow(Amqp::EventBroadcaster).to receive(:with_broadcaster).and_yield(mock_event_broadcaster)
    allow(mock_event_broadcaster).to receive(:broadcast).with(
      {
        :routing_key => "info.events.legacy_enrollment_vocabulary.uploaded",
        :app_id =>  "gluedb",
        :headers =>  {
          "file_name" => File.basename(file_path),
          "kind" => 'maintenance',
          "submitted_by"  => user.email,
          "bypass_validation" => "false",
          "redmine_ticket" => "1234"
        }
      },
      File.read(file_path)
    )
    visit new_vocab_upload_path

    choose 'Maintenance'
    fill_in "vocab_upload[redmine_ticket]", with: "1234"

    attach_file('vocab_upload_vocab', file_path)
    expect(policy1.term_for_np).to eq false
    click_button "Upload"
    expect(policy.term_for_np).to eq true
    expect(page).to have_content 'Uploaded successfully.'
  end

  scenario 'non carefirst subscriber member canceled' do
    file_path = Rails.root + "spec/support/fixtures/cancel/non_carefirst_subscriber_cancel.xml"
    allow(Amqp::EventBroadcaster).to receive(:with_broadcaster).and_yield(mock_event_broadcaster)
    allow(mock_event_broadcaster).to receive(:broadcast).with(
      {
        :routing_key => "info.events.legacy_enrollment_vocabulary.uploaded",
        :app_id =>  "gluedb",
        :headers =>  {
          "file_name" => File.basename(file_path),
          "kind" => 'maintenance',
          "submitted_by"  => user.email,
          "bypass_validation" => "false",
          "redmine_ticket" => "1234"
        }
      },
      File.read(file_path)
    )
    visit new_vocab_upload_path

    choose 'Maintenance'
    fill_in "vocab_upload[redmine_ticket]", with: "1234"

    attach_file('vocab_upload_vocab', file_path)
    policy.enrollees.first.update_attributes!(emp_stat: 'active', coverage_end: nil)
    policy.update_attributes!(aasm_state: 'resubmitted', term_for_np: false)
    expect(policy.term_for_np).to eq false
    click_button "Upload"
    policy.reload
    expect(policy.term_for_np).to eq true
    expect(page).to have_content 'Uploaded successfully.'
  end

  scenario 'incorrect premium total' do
    visit new_vocab_upload_path

    choose 'Maintenance'
    fill_in "vocab_upload[redmine_ticket]", with: "1234"

    file_path = Rails.root + "spec/support/fixtures/cancel/incorrect_premium_total.xml"
    attach_file('vocab_upload_vocab', file_path)

    click_button "Upload"

    expect(page).to have_content 'Failed to Upload.'
    expect(page).to have_content 'premium_amount_total is incorrect'
  end
end
