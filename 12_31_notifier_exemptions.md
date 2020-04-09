# Areas

This outlines the areas we need to correct to prevent 1095A update notification from being fired when we are 'only' setting 12/31 end dates on IVL policies.

This includes cases where we need to switch carriers and do end up transmitting an end-of-year termination.

# Cases To Correct

1. COR
   1. *carrier_switch.rb
   2. *carrier_switch_renewal.rb
   3. cobra_switchover.rb
   4. dependent_drop.rb
   5.  market_change.rb
   6.  new_policy_reinstate.rb
   10. renewal_dependent_add.rb
   11. renewal_dependent_drop.rb
   12. termination.rb
2. UI Initiated Changes
3. EDI Import

# Cases to Ignore and Why

1. Individual Updates - triggers no policy end-date changes
2. Observer - we can't rely on versioning of sub-documents to be correct, thus we can't solve this problem at a single location by version comparison
3. COR
   1. assistance_change.rb - triggers no kinds of termination
   2. active_renewal.rb - triggers no kinds of termination
   3. cobra_reinstate.rb - triggers no kinds of termination
   4. dependent_add.rb - triggers no kinds of termination
   5. initial_enrollment.rb - triggers no kinds of termination
   6. passive_renewal.rb - triggers no kinds of termination
   7.  plan_change.rb - can't happen at end of year, must happen during the year
   8.  plan_change_dependent_add.rb - can't happen at end of year, must happen during the year
   9.  plan_change_dependent_drop.rb - can't happen at end of year, must happen during the year
   10. terminate_policy_with_earlier_date.rb - not possible for the termination date to be the same as the latest possible termination date (which is the end of the year)
   11. reinstate.rb - triggers no kinds of termination
   12. reselection_of_existing_coverage.rb - triggers no kinds of termination
   13. cobra_new_policy_reinstate.rb - cobra doesn't apply to IVL
   14. cobra_new_policy_switchover.rb - cobra doesn't apply to IVL