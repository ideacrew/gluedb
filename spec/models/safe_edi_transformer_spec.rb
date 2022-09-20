require "rails_helper"

describe SafeEdiTransformer do
  subject do
    Class.new do
      include SafeEdiTransformer
    end.new
  end
  
  it "handles ASCII_8BIT" do
    a8bit_string = "With A QUOTIE“".force_encoding(Encoding::ASCII_8BIT)
    expect(subject.safe_transform(a8bit_string)).to eq("With A QUOTIE&quot;")
  end
end