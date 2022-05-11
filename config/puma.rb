environment ENV.fetch("RAILS_ENV", "development")
bind "tcp://0.0.0.0:#{ENV['PORT'] || 3000}"
pidfile "/edidb/tmp/pids/puma.pid"
threads 1,1
