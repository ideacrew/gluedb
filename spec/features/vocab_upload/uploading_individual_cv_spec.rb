require 'rails_helper'

feature 'uploading individual CV', :dbclean => :after_each do
  let(:mock_event_broadcaster) do
    instance_double(Amqp::EventBroadcaster)
  end

  let!(:member) { FactoryGirl.build :member, hbx_member_id: '123456' }
  let!(:child_member) { FactoryGirl.build :member, hbx_member_id: '789012' }
  let!(:person) { FactoryGirl.create :person, name_first: 'Example', name_last: 'Person', members: [ member ] }
  let!(:policy1) { Policy.new(eg_id: '1', enrollees: [enrollee1, child_enrollee1], plan: plan, carrier: carrier ) }
  let!(:policy2) { Policy.new(eg_id: '2', enrollees: [enrollee2, child_enrollee2], plan: plan, carrier: carrier, employer_id: nil, aasm_state: "terminated", term_for_np: true ) }
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
  let!(:child_enrollee1) do
    Enrollee.new(
      m_id: child_member.hbx_member_id,
      benefit_status_code: 'active',
      employment_status_code: 'active',
      relationship_status_code: 'child',
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
  let!(:child_enrollee2) do
    Enrollee.new(
      m_id: child_member.hbx_member_id,
      benefit_status_code: 'active',
      employment_status_code: 'terminated',
      relationship_status_code: 'child',
      coverage_start: Date.new(2020,1,1),
      coverage_end: Date.new(2020,3,31))
  end
  let!(:enrollee3) do
    Enrollee.new(
      m_id: member.hbx_member_id,
      benefit_status_code: 'active',
      employment_status_code: 'terminated',
      relationship_status_code: 'self',
      coverage_start: Date.new(2020,4,1),
      coverage_end: Date.new(2020,4,1))
  end

  let!(:child_enrollee3) do
    Enrollee.new(
      m_id: child_member.hbx_member_id,
      benefit_status_code: 'active',
      employment_status_code: 'terminated',
      relationship_status_code: 'child',
      coverage_start: Date.new(2020,4,1),
      coverage_end: Date.new(2020,4,1))
  end
  let!(:policy3) { Policy.new(eg_id: '740893', enrollees: [enrollee3, child_enrollee3], plan: plan, carrier: carrier,  employer_id: nil, aasm_state: "canceled") }
  let!(:policy) { FactoryGirl.create(:policy, eg_id: '7654321', employer_id: nil, aasm_state: "terminated", term_for_np: true ) }
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
    policy1.save!
    policy2.save!
    policy3.save!
    allow(Observers::PolicyUpdated).to receive(:notify).with(policy2)
    allow(Observers::PolicyUpdated).to receive(:notify).with(policy)
  end

  scenario 'A carefirst reinstate CV successful upload' do
    file_path = Rails.root + "spec/support/fixtures/individual_enrollment/carefirst_correct.xml"
    allow(Amqp::EventBroadcaster).to receive(:with_broadcaster).and_yield(mock_event_broadcaster)
    allow(mock_event_broadcaster).to receive(:broadcast).with(
      {
        :routing_key => "info.events.legacy_enrollment_vocabulary.uploaded",
        :app_id =>  "gluedb",
        :headers =>  {
          "file_name" => File.basename(file_path),
          "kind" => 'initial_enrollment',
          "submitted_by"  => user.email,
          "bypass_validation" => "false",
          "redmine_ticket" => "1234"
        }
      },
      File.read(file_path)
    )
    visit new_vocab_upload_path

    choose 'Initial Enrollment'
    fill_in "vocab_upload[redmine_ticket]", with: "1234"

    attach_file('vocab_upload_vocab', file_path)
    terminated_policy = Policy.where(eg_id: '2').first
    expect(terminated_policy.term_for_np).to eq true
    click_button "Upload"
    terminated_policy.reload
    expect(terminated_policy.term_for_np).to eq false
    expect(page).to have_content 'Uploaded successfully.'
  end

  scenario 'A non carefirst reinstate CV successful upload' do
    file_path = Rails.root + "spec/support/fixtures/individual_enrollment/non_carefirst_correct.xml"
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

    expect(policy.term_for_np).to eq true
    click_button "Upload"
    policy.reload
    expect(policy.term_for_np).to eq false
    expect(page).to have_content 'Uploaded successfully.'
  end

  scenario 'A carefirst reinstated canceled CV successful upload' do
    file_path = Rails.root + "spec/support/fixtures/individual_enrollment/carefirst_reinstate.xml"
    allow(Amqp::EventBroadcaster).to receive(:with_broadcaster).and_yield(mock_event_broadcaster)
    allow(mock_event_broadcaster).to receive(:broadcast).with(
      {
        :routing_key => "info.events.legacy_enrollment_vocabulary.uploaded",
        :app_id =>  "gluedb",
        :headers =>  {
          "file_name" => File.basename(file_path),
          "kind" => 'initial_enrollment',
          "submitted_by"  => user.email,
          "bypass_validation" => "false",
          "redmine_ticket" => "1234"
        }
      },
      File.read(file_path)
    )
    visit new_vocab_upload_path

    choose 'Initial Enrollment'
    fill_in "vocab_upload[redmine_ticket]", with: "1234"

    attach_file('vocab_upload_vocab', file_path)
    canceled_policy = Policy.where(eg_id: '740893').first
    terminated_policy = Policy.where(eg_id: '2').first
    expect(terminated_policy.term_for_np).to eq true
    expect(terminated_policy.aasm_state).to eq "terminated"
    expect(canceled_policy.term_for_np).to eq false
    expect(canceled_policy.aasm_state).to eq "canceled"
    click_button "Upload"
    terminated_policy.reload
    expect(terminated_policy.term_for_np).to eq false
    expect(page).to have_content 'Uploaded successfully.'
  end

  scenario 'A carefirst termination CV successful upload' do
    file_path = Rails.root + "spec/support/fixtures/individual_enrollment/term_carefirst_correct.xml"
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
    terminated_policy = Policy.where(eg_id: '2').first
    expect(terminated_policy.term_for_np).to eq true
    click_button "Upload"
    terminated_policy.reload
    expect(terminated_policy.term_for_np).to eq false
    expect(page).to have_content 'Uploaded successfully.'
  end

  scenario 'A non carefirst termination CV successful upload' do
    file_path = Rails.root + "spec/support/fixtures/individual_enrollment/term_non_carefirst_correct.xml"
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

    expect(policy.term_for_np).to eq true
    click_button "Upload"
    policy.reload
    expect(policy.term_for_np).to eq false
    expect(page).to have_content 'Uploaded successfully.'
  end

  scenario 'no file is selected' do
    visit new_vocab_upload_path

    choose 'Initial Enrollment'
    fill_in "vocab_upload[redmine_ticket]", with: "1234"

    click_button "Upload"

    expect(page).not_to have_content 'Uploaded successfully.'
  end

# Premium validator check has been removed
  # scenario 'enrollee\'s premium is incorrect' do
  #   visit new_vocab_upload_path

  #   choose 'Initial Enrollment'
  #   fill_in "vocab_upload[redmine_ticket]", with: "1234"

  #   file_path = Rails.root + "spec/support/fixtures/individual_enrollment/incorrect_premium.xml"
  #   attach_file('vocab_upload_vocab', file_path)

  #   click_button "Upload"

  #   expect(page).to have_content 'premium_amount is incorrect'
  #   expect(page).to have_content 'Failed to Upload.'

  # end

  scenario 'premium amount total is incorrect' do
    visit new_vocab_upload_path

    choose 'Initial Enrollment'
    fill_in "vocab_upload[redmine_ticket]", with: "1234"

    file_path = Rails.root + "spec/support/fixtures/individual_enrollment/incorrect_total.xml"
    attach_file('vocab_upload_vocab', file_path)

    click_button "Upload"

    expect(page).to have_content 'premium_amount_total is incorrect'
    expect(page).to have_content 'Failed to Upload.'
  end

  scenario 'responsible amount is incorrect' do
    visit new_vocab_upload_path

    choose 'Initial Enrollment'
    fill_in "vocab_upload[redmine_ticket]", with: "1234"

    file_path = Rails.root + "spec/support/fixtures/individual_enrollment/incorrect_responsible.xml"
    attach_file('vocab_upload_vocab', file_path)

    click_button "Upload"

    expect(page).to have_content 'total_responsible_amount is incorrect'
    expect(page).to have_content 'Failed to Upload.'
  end

  # Premium validator check has been removed
  # feature 'Handling premium not found error' do
  #   given(:premium) { nil }
  #   scenario 'premium table is not in the system' do
  #     visit new_vocab_upload_path

  #     choose 'Initial Enrollment'
  #     fill_in "vocab_upload[redmine_ticket]", with: "1234"

  #     file_path = Rails.root + "spec/support/fixtures/individual_enrollment/correct.xml"
  #     attach_file('vocab_upload_vocab', file_path)

  #     click_button "Upload"

  #     expect(page).to have_content 'Premium was not found in the system.'
  #     expect(page).to have_content 'Failed to Upload.'
  #   end
  # end
end
