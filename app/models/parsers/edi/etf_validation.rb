module Parsers
  module Edi
    class EtfValidation
      include ActiveModel
      include ActiveModel::Validations

      attr_accessor :file_name, :message_type, :etf_loop
      validate :on_blacklist

      validate :has_pre_amt_tot
      validate :has_all_premium_amounts
      validate :has_right_number_of_subscribers
      validate :subscriber_refs_match
      validate :has_eg_id
      validate :has_valid_employer
      validate :plan_exists
      validate :no_bogus_broker
      validate :has_st_segment

      def initialize(f_name, mt, el, carrier, blist, i_cache)
        @file_name = f_name
        @message_type = mt
        @etf_loop = el
        @carrier = carrier
        @blacklisted_bgns = blist
        @import_cache = i_cache
      end

      def has_st_segment
        if @etf_loop["ST"].blank?
          log_error(:etf_loop, "has no ST segment")
        end
      end

      def on_blacklist
        bgn_two = @etf_loop["BGN"][2]
        if @blacklisted_bgns.include?(bgn_two)
          log_error(:etf_loop, "is blacklisted by BGN02")
        end
      end

      def has_eg_id
        member_loops = @etf_loop["L2000s"]
        if (member_loops.any? { |ml| ml["L2300s"].first.blank? })
            log_error(:etf_loop, "is missing coverage loops")
        else
          if !subscriber_loop.blank?
            unless (subscriber_loop["L2300s"].first["REFs"].any? { |r| r[1] == "1L" })
              log_error(:etf_loop, "does not have an enrollment id")
            end
          end
        end
      end

      def has_valid_employer
        # emp_seg = @etf_loop.L1000A.N1
        # return(nil) if emp_seg.N102 == "DC0"
        # if emp_seg.N104.length < 7
        #   log_error(:etf_loop, "has an invalid employer id")
        # end
      end

      def subscriber_refs_match
=begin
    if right_subscriber_count
      sl = subscriber_loop
      si_loop = sl.REF.to_a.detect do |r|
        r.REF01 == "0F"
      end
      mi_loop = sl.REF.to_a.detect do |r|
        r.REF01 == "17"
      end
      if si_loop.nil?
        errors.add(:etf_loop, "has no subscriber_id for the subscriber")
      end
      if mi_loop.nil?
        errors.add(:etf_loop, "has no member_id for the subscriber")
      end
      if !(si_loop.nil? || mi_loop.nil?)
        unless si_loop.REF02.strip == mi_loop.REF_02.strip
          errors.add(:etf_loop, "has mis-matching subscriber and member ids in the subscriber loop")
        end
      end
    end
=end
      end

      def has_pre_amt_tot
        if right_subscriber_count
          if !tsf_exists?(subscriber_loop, "PRE AMT TOT")
            log_error(:etf_loop, "has no PRE AMT TOT")
          end
        end
      end

      # FIXME: 15769 - Require premiums only if not composite-rated
      def has_all_premium_amounts
        if right_subscriber_count
          unless (@etf_loop["L2000s"].all?{ |l| tsf_exists?(l, "PRE AMT 1") })
            log_error(:etf_loop, "is missing PRE AMT 1")
          end
        end
      end

      def has_right_number_of_subscribers
        if subscriber_count > 1
          log_error(:etf_loop, "has too many subscribers")
        elsif subscriber_count < 1
          log_error(:etf_loop, "has no subscriber")
        end
      end

      def plan_exists
        s_loop = subscriber_loop
        if !s_loop.blank?
          pol_loop = Parsers::Edi::Etf::PolicyLoop.new(s_loop["L2300s"].first)
          if pol_loop.empty?
            log_error(:etf_loop, "has no valid plan")
          else
            plan = nil
            coverage_start = Maybe.new(pol_loop.coverage_start).fmap { |cs| Date.parse(cs) }.value
            if !coverage_start.blank?
              if(is_shop?)
                employer_loop = Etf::EmployerLoop.new(@etf_loop["L1000A"]["N1"])
                employer = nil
                if employer_loop.specified_as_group?
                  employer = Employer.find_for_carrier_and_group_id(@carrier.id, employer_loop.group_id)
                  if employer.blank?
                    employer = Employer.find_for_fein(employer_loop.fein)
                  end
                else
                  employer = Employer.find_for_fein(employer_loop.fein)
                end
                if employer.blank?
                  errors.add(:etf_loop, "has invalid employer: #{employer_loop.fein}")
                  puts "has invalid employer: #{employer_loop.fein}"
                  return
                end
                plan_years = PlanYear.where({
                  :employer_id => employer.id,
                  :start_date => { "$lte" => coverage_start }
                })
                if plan_years.empty?
                  log_error(:etf_loop, "has no valid plan year")
                  return
                end
                plan_year = plan_years.sort_by{|py| py.start_date}.last.start_date.year
              else
                plan_year = coverage_start.year
              end
              plan = @import_cache.lookup_plan(pol_loop.hios_id, plan_year)
            else
              eg_id = pol_loop.eg_id
              hios = pol_loop.hios_id
              plan = Maybe.new(Policy.find_for_group_and_hios(eg_id, hios)).plan.value
            end
            if plan.blank?
              log_error(:etf_loop, "has no valid plan")
            end
          end
        end
      end

      def no_bogus_broker
        broker_loop = Etf::BrokerLoop.new(@etf_loop["L1000C"])
        return true if !broker_loop.valid?
        found_broker = Broker.find_by_npn(broker_loop.npn)
        if found_broker.nil?
          log_error(:etf_loop, "has an invalid broker")
        end
      end

      private

      def is_shop?
        !(@etf_loop["L1000A"]["N1"][4] == ExchangeInformation.receiver_id)
      end

      def tsf_exists?(target_loop, label)
        target_loop["L2700s"].any? do |lth|
          lth["L2750"]["N1"][2].strip == label
        end
      end

      def right_subscriber_count
        (subscriber_count == 1)
      end

      def subscriber_count
        @etf_loop["L2000s"].count do |l2000|
          l2000["INS"][2].strip == "18"
        end
      end

      def subscriber_loop
        @subscriber_loop ||= @etf_loop["L2000s"].detect do |l2000|
          l2000["INS"][2].strip == "18"
        end
      end

      def log_error(attr, msg)
        errors.add(attr, msg)
        #        ParserLog.log(@file_name, @message_type, attr.to_s + " " + msg, @etf_loop.to_s)
      end
    end
  end
end
