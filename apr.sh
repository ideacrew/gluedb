echo "audit policy report 2022 started" $(date)
bundle exec rails r lib/audit_policy_report.rb -e production
echo "audit policy report completed" $(date)
sleep 30

sed -i 's/2022/2023/' lib/audit_policy_report.rb
echo "audit policy report 2023 started" $(date)
bundle exec rails r lib/audit_policy_report.rb -e production
echo "audit policy report completed" $(date)
