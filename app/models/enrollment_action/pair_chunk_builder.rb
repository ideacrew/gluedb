module EnrollmentAction
  class PairChunkBuilder
    def self.call(enrollments)
      aw = ArrayWindow.new(enrollments)
      aw.chunk_adjacent do |a, b|
        !a.is_adjacent_to?(b)
      end
    end
  end
end