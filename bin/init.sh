#!/bin/bash
# "init" for the dev container, already running as target user
# start our main tmux session
# exit the container when our tmux session ends

progname="${0##*/}"

log() {
  echo "$(date): $progname: ""$@"
}

err() {
  log "$@" >&2
}

usage() {
  echo "Usage: $progname [-d docker_gid] [-u target_uid]"
}

# catch an INT (^C) from a 'docker run -i' and a TERM from 'docker stop'
trap "exit 2" SIGINT TERM

while getopts "d:u:" opt; do
  case "$opt" in
    d)
      docker_gid=$OPTARG
      ;;
    u)
      target_uid=$OPTARG
      ;;
    *)
      err "$opt: invalid option"
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ -z "$USERNAME" ]]; then
  err "\$USERNAME must be set to the target user"
  exit 1
fi
target_user=$USERNAME

if [[ -n "$docker_gid" ]]; then
  sudo groupmod -g "$docker_gid" docker
  if [[ $? -ne 0 ]]; then
    err "failed to set docker gid to $docker_gid"
    exit 3
  fi
fi

if [[ -n "$target_uid" ]]; then
  # "usermod -u" not used; it does a recursive chown of the user's home
  sudo sed -i -e "s/^${target_user}:x:\(\d+\):/${target_user}:x:${target_uid}:/" /etc/passwd
  if [[ $? -ne 0 ]]; then
    err "failed to set $target_user uid to $target_uid"
    exit 4
  fi
fi

target_home="$(getent passwd $target_user | cut -d: -f6)"
cd "$target_home" || exit 5

tmux_name="devshell-${DEVSHELL}"
log "starting tmux dev session \"$tmux_name\" for $target_user in $(pwd)"
sudo -u "$target_user" --preserve-env=DEVSHELL tmux new-session -d -s "$tmux_name"
rc=$?
if [[ $rc -ne 0 ]]; then
  err "failed to start tmux dev session (exit code $rc)"
  exit 6
fi

tmux_pid="$(pgrep -f 'tmux new-session')"
if [[ -z $tmux_pid ]]; then
  err "can't find newly launched tmux pid"
  exit 7
fi
echo "started tmux (pid $tmux_pid)"

while ps -p "$tmux_pid" >/dev/null; do
  sleep 1
done

log "shutting down, tmux dev session ended for $target_user"
exit 0
