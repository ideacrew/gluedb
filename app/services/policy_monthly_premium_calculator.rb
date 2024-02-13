module Services
  class PolicyMonthlyPremiumCalculator
    
    def initialize(policy_disposition:, calendar_year:, silver_plan: nil)
    	@policy_disposition = policy_disposition
      @calendar_year = calendar_year
      @silver_plan = silver_plan
    end

    def premiums_by_months
    	return @premiums_by_months if defined? @premiums_by_months
    	policy_start_date = @policy_disposition.start_date
    	policy_end_date = @policy_disposition.end_date
      @premiums_by_months = (policy_start_date.month..policy_end_date.month).inject({}) do |premiums_by_month, calendar_month|
        premiums_by_month[calendar_month] = calculate_premiums_for_month(calendar_month, @policy_disposition.policy)
        premiums_by_month
    	end
    end

    def calculate_premiums_for_month(calendar_month, policy)
      calendar_month_begin = Date.new(@calendar_year, calendar_month, 1)
      calendar_month_end = calendar_month_begin.end_of_month
      premium_dates = if (calendar_month_begin..calendar_month_end).cover?(@policy_disposition.end_date)
        [@policy_disposition.end_date]
      else
        [calendar_month_end]
      end
      premium_dates << calendar_month_begin if @policy_disposition.start_date <= calendar_month_begin
      policy.enrollees.each do |enrollee|
        next if enrollee.canceled? || enrollee.coverage_start.blank?
        premium_dates << enrollee.coverage_start if (calendar_month_begin..calendar_month_end).cover?(enrollee.coverage_start)
        if (calendar_month_begin..calendar_month_end).cover?(enrollee.coverage_end) && enrollee.coverage_end != calendar_month_end
          premium_dates << (enrollee.coverage_end + 1.day)
        end
      end
      sorted_premium_dates = premium_dates.compact.uniq.sort
      month_premiums = sorted_premium_dates.each_with_index.collect do |date, index|
        next if date == sorted_premium_dates[-1]
        {
          premium_start_date: date,
          premium_end_date: premium_end_date(sorted_premium_dates, index, calendar_month_end),
          premium: @policy_disposition.as_of(date, @silver_plan).ehb_premium
        }
      end.compact
    end

    def premium_end_date(sorted_premium_dates, index, calendar_month_end)
      if sorted_premium_dates[index + 1] == calendar_month_end
        calendar_month_end
      else
        sorted_premium_dates[index + 1].prev_day
      end
    end

    def ehb_premium_for(calendar_month)
    	premiums_by_dates = premiums_by_months[calendar_month]
      calendar_start_date = Date.new(@calendar_year, calendar_month, 1)
      calendar_end_date = calendar_start_date.end_of_month
      calendar_days = (calendar_start_date..calendar_end_date).count
      premiums_by_dates.sum do |premium_date_hash|
        (premium_date_hash[:premium]/calendar_days)*(premium_date_hash[:premium_start_date]..premium_date_hash[:premium_end_date]).count.to_f
      end.round(2)
    end
  end
end
