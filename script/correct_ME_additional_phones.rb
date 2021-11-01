people_with_both_phones = Person.where({"phones.1" => {"$exists" => true}})

people_at_issue_count = 0

people_with_both_phones_before = people_with_both_phones.count

excluded_members = ["1001531", "1003472", "1005378", "1006538", "1007935", "1011056", "1012689", "1015116", "1016782", "1016905", "1017631", "1018276", "1018396", "1020309", "1020325", "1025907", "1029759", "1029931", "1033939", "1037617", "1039489", "1040535", "1040931", "1044669", "1051678", "1053998", "1054864", "1057390", "1057788", "1062256", "1062712", "1066107", "1068112", "1069724", "1070654", "1071033", "1100089", "1101077", "1102700", "1102702", "1102711", "1102713", "1102720", "1102726", "1102745", "1102747", "1102749", "1102750", "1102755", "1102758", "1102761", "1102767", "1102780", "1102786", "1102788", "1102796", "1102797", "1102801", "1102808", "1102809", "1102815", "1102816", "1102819", "1102836", "1102837", "1102854", "1102860", "1102868", "1102882", "1102890", "1102901", "1102906", "1102913", "1102914", "1102917", "1102929", "1102931", "1102933", "1102936", "1102939", "1102948", "1102949", "1102954", "1102955", "1102960", "1102968", "1102969", "1102975", "1102993", "1102999", "1103010", "1103016", "1103035", "1103048", "1103051", "1103056", "1103064", "1103074", "1103075", "1103077", "1103079", "1103082", "1103084", "1103085", "1103088", "1103102"]

people_with_both_phones.each do |person|
  sorted_phones = person.phones.sort_by(&:phone_type)
  if (sorted_phones[0].phone_type == "home") && (sorted_phones[1].phone_type == "mobile")
    if (sorted_phones[0].phone_number == sorted_phones[1].phone_number)
      if !(person.members.any? { |m| excluded_members.include? m.hbx_member_id})
        sorted_phones[0].destroy
        people_at_issue_count += 1
      end
    end
  end
end

people_with_both_phones_after = people_with_both_phones.count

puts "Total people with multiple phones: #{people_with_both_phones_before}"
puts "People at issue: #{people_at_issue_count}"
puts "People with multiple phones after correction: #{people_with_both_phones_after}"