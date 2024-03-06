module Queries
  class PoliciesWithNoFamilies
    
    # returns policies that do not belong to any family
    def execute
      policy_ids = Family.collection.aggregate([
        {"$skip" => 0},
        {"$limit" => 100000},
        {"$unwind" => '$households'},
        {"$unwind" => '$households.hbx_enrollments'},
        {"$match" => {"households.hbx_enrollments.kind" => {"$ne" => "employer_sponsored"}}},
        {
          "$group" => {
            "_id" => {
              "id" => "$households.hbx_enrollments._id"
              },
              "policy_id" => {"$last" => "$households.hbx_enrollments.policy_id"},
            }
            },
            {
              "$project" => {
               "_id" => 1,
               "policy_id" => "$policy_id",
             }
           }
           ]).collect{|r| r['policy_id']}.uniq

      next_policy_ids = Family.collection.aggregate([
        {"$skip" => 100000},
        {"$limit" => 100000},
        {"$unwind" => '$households'},
        {"$unwind" => '$households.hbx_enrollments'},
        {"$match" => {"households.hbx_enrollments.kind" => {"$ne" => "employer_sponsored"}}},
        {
          "$group" => {
            "_id" => {
              "id" => "$households.hbx_enrollments._id"
              },
              "policy_id" => {"$last" => "$households.hbx_enrollments.policy_id"},
            }
            },
            {
              "$project" => {
               "_id" => 1,
               "policy_id" => "$policy_id",
             }
           }
           ]).collect{|r| r['policy_id']}.uniq
      more_policy_ids = Family.collection.aggregate([
        {"$skip" => 200000},
        {"$unwind" => '$households'},
        {"$unwind" => '$households.hbx_enrollments'},
        {"$match" => {"households.hbx_enrollments.kind" => {"$ne" => "employer_sponsored"}}},
        {
          "$group" => {
            "_id" => {
              "id" => "$households.hbx_enrollments._id"
              },
              "policy_id" => {"$last" => "$households.hbx_enrollments.policy_id"},
            }
            },
            {
              "$project" => {
               "_id" => 1,
               "policy_id" => "$policy_id",
             }
           }
           ]).collect{|r| r['policy_id']}.uniq
      all_policy_ids = next_policy_ids + policy_ids + more_policy_ids

      policies = Policy.where(:id.nin => all_policy_ids).individual_market
    end
  end
end
