#!/bin/bash

pidfile=/data/db/mongodpid

mongod --fork --syslog --noauth --pidfilepath "$pidfile"

tries=30
while true; do
  if ! { [ -s "$pidfile" ] && ps "$(< "$pidfile")" &> /dev/null; }; then
    # bail ASAP if "mongod" isn't even running
    echo >&2
    echo >&2 "error: mongod does not appear to have stayed running -- perhaps it had an error?"
    echo >&2
    exit 1
  fi
  if mongo 'admin' --eval 'quit(0)' &> /dev/null; then
    # success!
    break
  fi
  (( tries-- ))
  if [ "$tries" -le 0 ]; then
    echo >&2
    echo >&2 "error: $originalArgOne does not appear to have accepted connections quickly enough -- perhaps it had an error?"
    echo >&2
    exit 1
  fi
  sleep 1
done

mongo < create_users.js

sleep 3

mongod --shutdown
rm -f "$pidfile"