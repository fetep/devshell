#!/bin/bash
# a helper to attach to the "dev" session.
# when starting a fresh devshell docker instance, running 'tmux attach'
# too soon results in an error, so instead run this

progname=$(basename "$0")

set -euo pipefail

log() {
  echo "$progname: ""$@"
}

err() {
  log "$@" >&2
}

count=0
while ! tmux has-session -t dev >/dev/null 2>&1; do
  count=$((count+1))
  if [[ $count > 5 ]]; then
    err "cannot find dev tmux session"
    break
  fi
  sleep 1
done

exec tmux attach -t dev
