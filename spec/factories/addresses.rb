FactoryGirl.define do
  factory :address do
    address_type 'home'
    address_1 '1234 Awesome Street'
    address_2 '#123'
    city 'Washington'
    state 'DC'
    zip '20002'

    trait :with_invalid_address_type do
      address_type 'invalid'
    end

    trait :without_address_1 do
      address_1 ' '
    end

    trait :without_city do
      city ' '
    end

    trait :without_state do
      state ' '
    end

    trait :without_zip do
      zip ' '
    end

    factory :invalid_address, traits: [:without_address_1, 
      :without_city, :without_state, :without_zip]
  end
end