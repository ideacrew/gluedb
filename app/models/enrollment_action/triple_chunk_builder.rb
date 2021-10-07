module EnrollmentAction
  class TripleChunkBuilder
    def self.call(enrollments)
      check_match(enrollments)
    end

    def self.check_match(enrollments)
      return PairChunkBuilder.call(enrollments) if enrollments.length < 3
      iterator = NSetIterator.new(3, enrollments)

      matched = iterator.detect do |items|
        before, rest, after = items
        !EnrollmentAction::Base.check_for_action_3(rest).nil?
      end
      if matched
        before_matches, matched_chunk, rest = matched
        PairChunkBuilder.call(before_matches) + [matched_chunk] + check_match(rest)
      else
        PairChunkBuilder.call(enrollments)
      end
    end
  end
end