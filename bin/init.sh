#!/bin/bash
# "init" for the dev container, already running as target user
# start our main tmux session
# exit the container when our tmux session ends

progname="${0##*/}"

set -euo pipefail

log() {
  echo "$(date): $progname: ""$@"
}

err() {
  log "$@" >&2
}

usage() {
  echo "Usage: $progname [-x] [-d docker_gid] [-u target_uid]"
}

# catch an INT (^C) from a 'docker run -i' and a TERM from 'docker stop'
trap "exit 2" SIGINT TERM

while getopts "d:u:x" opt; do
  case "$opt" in
    d)
      docker_gid=$OPTARG
      ;;
    u)
      target_uid=$OPTARG
      ;;
    x)
      set -x
      ;;
    *)
      err "$opt: invalid option"
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ -z ${USER:-} ]]; then
  err "\$USER must be set to the target user"
  exit 1
fi

if [[ -n ${docker_gid:-} ]]; then
  sudo groupmod -g "$docker_gid" docker
  if [[ $? -ne 0 ]]; then
    err "failed to set docker gid to $docker_gid"
    exit 3
  fi
fi

if [[ -n ${target_uid:-} ]]; then
  # "usermod -u" not used; it does a recursive chown of the user's home
  sudo sed -i -e "s/^${USER}:x:\(\d+\):/${USER}:x:${target_uid}:/" /etc/passwd
  if [[ $? -ne 0 ]]; then
    err "failed to set $USER uid to $target_uid"
    exit 4
  fi
fi

target_home="$(getent passwd $USER | cut -d: -f6)"
cd "$target_home" || exit 5

tmux_name="devshell-${DEVSHELL}"
log "starting tmux dev session \"$tmux_name\" for $USER in $(pwd)"
sudo -u "$USER" --preserve-env=DEVSHELL tmux new-session -d -s "$tmux_name"
if [[ $? -ne 0 ]]; then
  err "failed to start tmux dev session"
  exit 6
fi

while sudo -u "$USER" tmux has-session -t "$tmux_name"; do
  sleep 10
done

log "shutting down, tmux dev session ended for $USER"
exit 0
