require 'rgl/adjacency'
require 'rgl/topsort'

module Handlers
  class EnrollmentEventEnrichHandler < ::Handlers::Base

    # Takes a 'bucket' of enrollment event notifications and transforms them
    # into a concrete set of enrollment actions.  We then invoke the step
    # after us once for each in that set.
    # [::ExternalEvents::EnrollmentEventNotification] -> [::EnrollmentAction::Base]
    def call(context)
      no_bogus_terms = discard_bogus_terms(context)
      no_bogus_plan_years = discard_bogus_plan_years(no_bogus_terms)
      sorted_actions = sort_enrollment_events(no_bogus_plan_years)
      clean_sorted_list = discard_bogus_renewal_terms(sorted_actions)
      enrollment_sets = chunk_enrollments(clean_sorted_list)
      resolve_actions(enrollment_sets).each do |action|
        super(action)
      end
    end

    def discard_bogus_plan_years(enrollments)
      filter = ::ExternalEvents::EnrollmentEventNotificationFilters::BogusPlanYear.new
      filter.filter(enrollments)
    end

    def discard_bogus_terms(enrollments)
      filter = ::ExternalEvents::EnrollmentEventNotificationFilters::BogusTermination.new
      filter.filter(enrollments)
    end

    # If we have a termination on a policy which crosses a plan year,
    # and that termination is the normal end day of the plan anyway,
    # discard the termination - we will generate our own and it confuses us.
    # We're doing this because we can't always rely on this termination being
    # generated by enroll.
    def discard_bogus_renewal_terms(enrollments)
      filter = ::ExternalEvents::EnrollmentEventNotificationFilters::BogusRenewalTermination.new
      filter.filter(enrollments)
    end

    def sort_enrollment_events(events)
      order_graph = RGL::DirectedAdjacencyGraph.new
      events.each do |ev|
        order_graph.add_vertex(ev)
      end
      events.permutation(2).each do |perm|
        a, b = perm
        a.edge_for(order_graph, b)
      end
      iter = order_graph.topsort_iterator
      results = []
      iter.each do |ev|
        results << ev
      end
      results
    end

    def chunk_enrollments(enrollments)
      ::EnrollmentAction::TripleChunkBuilder.call(enrollments)
    end

    def resolve_actions(enrollment_set)
      actions = []
      enrollment_set.each do |chunk|
        if !chunk.empty?
          action = EnrollmentAction::Base.select_action_for(chunk)
          if action
            actions << action
          end
        end
      end
      actions
    end
  end
end
