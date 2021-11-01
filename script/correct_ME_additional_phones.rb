people_with_both_phones = Person.where({"phones.1" => {"$exists" => true}})

people_at_issue_count = 0

people_with_both_phones_before = people_with_both_phones.count

people_with_both_phones.each do |person|
  sorted_phones = person.phones.sort_by(&:phone_type)
  if (sorted_phones[0].phone_type == "home") && (sorted_phones[1].phone_type == "mobile")
    if (sorted_phones[0].phone_number == sorted_phones[1].phone_number)
      sorted_phones[0].destroy
      people_at_issue_count += 1
    end
  end
end

people_with_both_phones_after = people_with_both_phones.count

puts "Total people with multiple phones: #{people_with_both_phones_before}"
puts "People at issue: #{people_at_issue_count}"
puts "People with multiple phones after correction: #{people_with_both_phones_after}"