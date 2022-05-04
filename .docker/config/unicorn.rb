working_directory "/edidb"
pid "/edidb/tmp/pids/unicorn.pid"
stderr_path "/edidb/log/unicorn.log"
stdout_path "/edidb/log/unicorn.log"

#listen "/edidb/tmp/unicorn.ap.sock"
listen 3000
worker_processes 10
timeout 180
