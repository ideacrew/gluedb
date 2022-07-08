module Parsers
  module Edi
    class PersonLoopValidator
      def validate_ins_combinations(person_loop, listener)
        valid = true
        change_code = person_loop.change_code
        case change_code
        when "021"
          allowed_values = ["28", "41"]
          valid = allowed_values.include?(person_loop.change_reason)
        when "030"
          valid = (person_loop.change_reason == "XN")
        when "024"
          valid = true
        when "025"
          allowed_values = ["EC", "41"]
          valid = allowed_values.include?(person_loop.change_reason)
        when "001"
          allowed_values = [
            "01",
            "02",
            "05",
            "29",
            "31",
            "32",
            "33",
            "EC"
          ]
          valid = allowed_values.include?(person_loop.change_reason)
        else
          valid = false
        end
        unless valid
          listener.invalid_ins_combination({
            :member_id => person_loop.member_id,
            :change_code => person_loop.change_code,
            :change_reason => person_loop.change_reason
          })
        end
        valid
      end

      def validate(person_loop, listener, policy)
        valid = true
        carrier_member_id = person_loop.carrier_member_id
        if person_loop.reinstate?
          listener.inbound_reinstate_blocked
          valid = false
        end
        return false unless valid
        return false unless validate_ins_combinations(person_loop, listener)
        if policy
          enrollee = policy.enrollee_for_member_id(person_loop.member_id)
          if enrollee.blank?
            listener.no_such_member(person_loop.member_id)
            valid = false
          end
        end
        policy_loop = person_loop.policy_loops.first
        if policy_loop
          is_stop = policy_loop.action == :stop
          if !is_stop
            if(carrier_member_id.blank?)
              listener.missing_carrier_member_id(person_loop)
              valid = false
            else
              listener.found_carrier_member_id(carrier_member_id)
            end
          end
          if policy
            if is_stop
               enrollee = policy.enrollee_for_member_id(person_loop.member_id)
               coverage_end_date = Date.strptime(policy_loop.coverage_end,"%Y%m%d") rescue nil
               if enrollee
                 if coverage_end_date.blank?
                   listener.termination_with_no_end_date({
                     :member_id => person_loop.member_id,
                     :coverage_end_string => policy_loop.coverage_end
                   })
                   valid = false
                 else
                   if (enrollee.coverage_start > coverage_end_date)
                     listener.coverage_end_before_coverage_start(
                       :coverage_end => policy_loop.coverage_end,
                       :coverage_start => enrollee.coverage_start.strftime("%Y%m%d"),
                       :member_id => person_loop.member_id
                     )
                     valid = false
                   end
                   max_end_date = (policy.coverage_year.end) rescue nil
                   if max_end_date
                     if max_end_date < coverage_end_date
                       listener.termination_date_after_expiration({
                         :coverage_end => policy_loop.coverage_end,
                         :expiration_date => max_end_date.strftime("%Y%m%d"),
                         :member_id => person_loop.member_id
                       })
                       valid = false
                     end
                   else
                     listener.indeterminate_policy_expiration({
                       :member_id => person_loop.member_id
                     })
                     valid = false
                   end
                   if enrollee.coverage_end
                     if person_loop.subscriber?
                       if enrollee.coverage_end < coverage_end_date
                         listener.termination_extends_coverage({
                           :coverage_end => policy_loop.coverage_end,
                           :enrollee_end => enrollee.coverage_end.strftime("%Y%m%d"),
                           :member_id => person_loop.member_id
                         })
                         valid = false
                       end
                     end
                   end
                 end
               end
            end
          end
        end
        return false unless valid
        if policy
          is_stop = policy_loop.action == :stop
          if !policy.is_shop?
            enrollee = policy.enrollee_for_member_id(person_loop.member_id)
            if (enrollee.coverage_start < Date.new(2015, 1, 1)) && is_stop
              listener.term_or_cancel_for_2014_individual(:member_id => person_loop.member_id, :date => policy_loop.coverage_end)
              valid = false
            end
          end
          if !is_stop
            enrollee = policy.enrollee_for_member_id(person_loop.member_id)
            if enrollee.coverage_start.present?
              effectuation_coverage_start = policy_loop.coverage_start
              policy_coverage_start = enrollee.coverage_start.strftime("%Y%m%d")
              if effectuation_coverage_start != policy_coverage_start
                listener.effectuation_date_mismatch(:policy => policy_coverage_start, :effectuation => effectuation_coverage_start, :member_id => person_loop.member_id)
                valid = false
              end
            end
          end
        end
        valid
      end
    end
  end
end
