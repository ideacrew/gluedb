file_name = ARGV[0]

transmissions = Protocols::X12::Transmission.where(
  "id" => {
    "$in" => [
               file_name
             ]
  }
)

transmissions.each do |t|
  t.transaction_set_enrollments.each do |tse|
    tse.body.remove!
    tse.delete
  end
  t.delete
end
