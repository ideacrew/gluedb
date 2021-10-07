module EnrollmentAction
  # See if the entire enrollment action set can be made to match a single
  # scenario.
  #
  # This is very rare and occurs currently only in the following cases:
  # * "buy last year and cancel my renewal"
  # * "add a dependent last year and cancel my renewal"
  class FullActionSetMatch
    def self.call(enrollments)
      check_match(enrollments)
    end

    def self.check_match(enrollments)
      return [false, []] unless enrollments.length == 2
      return [true, [enrollments]] if EnrollmentAction::Base.check_for_full_action(enrollments).present?
      # Here we are going to insert the special case of an exact match with
      # exactly that number of elements.  If true, we're going to return
      # a tuple of [true, enrollments]. Otherwise, [false, []].
      [false, []]
    end
  end
end