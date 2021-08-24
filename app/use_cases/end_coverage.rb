class EndCoverage
  include EnrollmentAction::NotificationExemptionHelper

  def initialize(action_factory, policy_repo = Policy)
    @policy_repo = policy_repo
    @action_factory = action_factory
  end

  def execute(request)
    @request = request
    affected_enrollee_ids = @request[:affected_enrollee_ids]
    return if affected_enrollee_ids.empty?

    @policy = @policy_repo.find(request[:policy_id])

    enrollees_not_already_canceled = @policy.enrollees.select { |e| !e.canceled? }
    update_policy(affected_enrollee_ids)
    notify_if_qualifies(request, @policy)
    alter_npt_flag(request, @policy)
    action = @action_factory.create_for(request)
    action_request = {
      policy_id: @policy.id,
      operation: request[:operation],
      reason: request[:reason],
      affected_enrollee_ids: request[:affected_enrollee_ids],
      include_enrollee_ids: enrollees_not_already_canceled.map(&:m_id),
      current_user: request[:current_user]
    }
    result = action.execute(action_request)
    result
  end

  def execute_csv(request, listener)
    @request = request

    @policy = @policy_repo.where({"_id" => request[:policy_id]}).first

    if (@policy.nil?)
      listener.no_such_policy(policy_id: request[:policy_id])
      listener.fail
      return
    end

    affected_enrollee_ids = @request[:affected_enrollee_ids]

    if (affected_enrollee_ids.nil? || affected_enrollee_ids.empty?)
      listener.fail(subscriber: request[:affected_enrollee_ids])
      return
    end

    if @policy.subscriber.coverage_ended?
      listener.policy_inactive(policy_id: request[:policy_id])
      listener.fail(subscriber: request[:affected_enrollee_ids])
      return
    end

    if request[:reason]== 'terminate' && @policy.enrollees.any?{ |e| e.coverage_start > request[:coverage_end].to_date }
      listener.end_date_invalid(end_date: request[:coverage_end])
      listener.fail(subscriber: request[:affected_enrollee_ids])
      return
    end

    enrollees_not_already_canceltermed= @policy.enrollees.select { |e| !e.canceled? && !e.terminated? }

    begin
      update_policy(affected_enrollee_ids)
    rescue PremiumCalcError => e
      listener.no_contribution_strategy(message: e.message)
      listener.fail(subscriber: request[:affected_enrollee_ids] )
    else
      action = @action_factory.create_for(request)

      action_request =
      {
        policy_id: @policy.id,
        operation: request[:operation],
        reason: request[:reason],
        affected_enrollee_ids: enrollees_not_already_canceltermed.map(&:m_id),
        include_enrollee_ids: enrollees_not_already_canceltermed.map(&:m_id),
        current_user: request[:current_user]
      }

      action.execute(action_request)
      listener.success(subscriber: request[:affected_enrollee_ids])
    end
  end

  private

  def update_policy(affected_enrollee_ids)
    subscriber = @policy.subscriber
    start_date  = @policy.subscriber.coverage_start
    plan = @policy.plan
    skip_recalc = affected_enrollee_ids.include?(subscriber.m_id) && (plan.year >= 2016)

    if @policy.is_shop? && !skip_recalc
      employer = @policy.employer
      strategy = employer.plan_years.detect{|py| py.start_date.year == plan.year}.contribution_strategy
      raise PremiumCalcError, "No contribution data found for #{employer.name} (fein: #{employer.fein}) in plan year #{@policy.plan.year}" if strategy.nil?
      plan_year = employer.plan_year_of(start_date)
      raise PremiumCalcError, "policy start date #{start_date} does not fall into any plan years of #{employer.name} (fein: #{employer.fein})" if plan_year.nil?
    else
      raise PremiumCalcError, "policy start date #{start_date} not in rate table for #{plan.year} plan #{plan.name} with hios #{plan.hios_plan_id} " unless plan.year == start_date.year || (start_date.year >= 2016 && @policy.is_shop?)
    end

    premium_calculator = Premiums::PolicyCalculator.new

    if(affected_enrollee_ids.include?(subscriber.m_id))
      premium_calculator.apply_calculations(@policy) unless skip_recalc
      end_coverage_for_everyone
    else
      end_coverage_for_ids(affected_enrollee_ids)
      enrollees = []
      rejected = @policy.enrollees.select{ |e| e.coverage_status == "inactive" }
      @policy.enrollees.reject!{ |e| e.coverage_status == "inactive" }
      premium_calculator.apply_calculations(@policy)
      active_enrollees = @policy.enrollees.select{ |e| e.coverage_status == "active" }
      enrollees << active_enrollees
      enrollees << rejected
      enrollees.flatten!
      enrollees.each do |e|
        e.policy = nil
      end
      @policy.enrollees.delete_all
      @policy.save!
      enrollees.each do |e|
        @policy.enrollees.build(
            Hash[e.attributes]
          )
      end
    end

    @policy.updated_by = @request[:current_user]
    @policy.save!
  end

  def end_coverage_for_everyone
    select_active(@policy.enrollees).each do |enrollee|
      end_coverage_for(enrollee, @request[:coverage_end])
    end

    @policy.total_premium_amount = final_premium_total
  end

  def end_coverage_for_ids(ids)
    enrollees = ids.map { |id| @policy.enrollee_for_member_id(id) }
    select_active(enrollees).each do |enrollee|
      end_coverage_for(enrollee, @request[:coverage_end])

      @policy.total_premium_amount -= enrollee.pre_amt
    end
  end

  def select_active(enrollees)
    enrollees.select { |e| e.coverage_status == 'active' }
  end

  def final_premium_total
    new_premium_total = 0
    if(@request[:operation] == 'cancel')
      @policy.enrollees.each { |e| new_premium_total += e.pre_amt }
    elsif(@request[:operation] == 'terminate')
      @policy.enrollees.each do |e|
        new_premium_total += e.pre_amt if e.coverage_end == @policy.subscriber.coverage_end
      end
    end
    new_premium_total
  end

  def end_coverage_for(enrollee, date)
    enrollee.coverage_status = 'inactive'
    enrollee.employment_status_code = 'terminated'

    if(@request[:operation] == 'cancel')
      enrollee.coverage_end = enrollee.coverage_start
    else
      enrollee.coverage_end = date
    end
  end

  def notify_if_qualifies(request, policy)
    if(request[:operation] == 'cancel')
      Observers::PolicyUpdated.notify(policy)
    else
      coverage_end_date = parse_coverage_end(request[:coverage_end])
      unless termination_event_exempt_from_notification?(policy, coverage_end_date)
        Observers::PolicyUpdated.notify(policy)
      end
    end
  end

  def parse_coverage_end(requested_coverage_end)
    return requested_coverage_end if requested_coverage_end.kind_of?(Date)
    if requested_coverage_end.split('/').first.size == 2
      Date.strptime(requested_coverage_end,"%m/%d/%Y")
    elsif requested_coverage_end.split('-').first.size == 2
      Date.strptime(requested_coverage_end,"%m-%d-%Y")
    end
  end

 def alter_npt_flag(request, policy)
    begin
      if policy.carrier.hbx_carrier_id == "116036" #hbx_carrier_id of CareFirst carrier
        alter_carefirst_npt_flag(request, policy)
      else
        alter_non_carefirst_npt_flag(request, policy)
      end
    rescue Exception => e
      puts e.to_s
      puts "policy_id: #{policy.id}"
    end
  end

  def alter_carefirst_npt_flag(request, policy)
    reinstate_policy_m_id = policy.subscriber.m_id
    pols = Person.where(authority_member_id: reinstate_policy_m_id).first.policies
    pols.each do |pol|
      if request[:operation] == 'cancel' && policy.aasm_state == 'submitted' && pol.versions.last.try(:term_for_np) == true && term_or_cancel_carefirst_policy_exists?(pol, policy)
        pol.update_attributes!(term_for_np: true)
        Observers::PolicyUpdated.notify(pol)
      end
    end
  end

  def term_or_cancel_carefirst_policy_exists?(pol, policy)
    reinstate_policy_plan_id = policy.plan_id
    reinstate_policy_carrier_id = policy.carrier_id
    term_policy_end_date = policy.policy_start - 1.day
    term_en_ids = pol.enrollees.map(&:m_id).sort
    reinstate_en_ids = policy.enrollees.map(&:m_id).sort
    return false unless pol.employer_id == nil
    return false unless (pol.aasm_state == "terminated" && pol.policy_end == term_policy_end_date)
    return false unless pol.plan_id.to_s == reinstate_policy_plan_id
    return false unless pol.carrier_id.to_s == reinstate_policy_carrier_id
    return false unless term_en_ids.count == reinstate_en_ids.count
    return false unless term_en_ids == reinstate_en_ids
    true
  end

  def alter_non_carefirst_npt_flag(request, policy)
    if request[:operation] == 'cancel' && policy.aasm_state == 'resubmitted'
      unless policy.versions.empty?
        last_version_npt = policy.versions.last.term_for_np
        policy.update_attributes!(term_for_np: last_version_npt)
      end
    end
  end

  class PremiumCalcError < StandardError

  end
end
