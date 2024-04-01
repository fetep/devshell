: ${DEVSHELL_IMAGE:=${USER}/devshell}

# stop + cleanup an existing devshell instance
_dev_kill() {
  local instance=$1
  local name="${USERNAME}-devshell-${instance}"
  echo "dev: stopping devshell instance $name"
  $docker stop "$name" >/dev/null 2>&1
  $docker rm "$name" >/dev/null 2>&1
}

# list running devshell instances. format is ${username}-devshell-${instance}
_dev_list() {
  docker ps --format '{{ .Names }}: {{ .Status }}' \
    | sed -n -e "s/^${USERNAME}-devshell-//p" \
    | sort
}

_dev_usage() {
  echo "Usage: dev [-f] [-h] [-l] [instance]"
  echo "-f          force repave (kill existing, start new)"
  echo "-h          print this help message"
  echo "-l          list running instances"
  echo "instance    devshell instance name (defaults to 1)"
}

# attach into devshell container, start container if not running
dev() {
  local docker="${DEVSHELL_DOCKER:-docker}"

  # don't allow starting/modifying a devshell from inside one
  if [[ -n $DEVSHELL ]]; then
    echo "dev: cannot run from inside a devshell" >&2
    return 1
  fi

  if [[ ! -x =docker ]]; then
    echo "dev: docker not installed" >&2
    return 1
  fi

  local force_repave=0 list=0 kill=0
  while getopts "fhkl" opt; do
    case "$opt" in
      f) force_repave=1 ;;
      h)
        _dev_usage
        return 0
        ;;
      k) kill=1 ;;
      l) list=1 ;;
      *)
        _dev_usage >&2
        return 1
        ;;
    esac
  done
  shift $((OPTIND-1))

  if [[ $# > 1 ]]; then
    echo "dev: too many arguments" >&2
    _dev_usage >&2
    return 1
  fi

  local instance=${1:-1}

  if [[ $list == 1 && $kill == 1 ]]; then
    echo "dev: -l and -k are mutually exclusive" >&2
    return 1
  elif [[ $list == 1 ]]; then
    _dev_list
    return $?
  elif [[ $kill == 1 ]]; then
    _dev_kill "$instance"
    return $?
  fi

  local name="${USERNAME}-devshell-${instance}"

  if [[ $force_repave == 1 ]]; then
    _dev_kill "$instance"
  fi

  local docker_status="$(docker inspect -f '{{ .State.Status }}' "$name" 2>/dev/null)"
  if [[ $docker_status == "stopped" ]]; then
    # re-build stopped containers with latest image (a fresh 'docker run')
    $docker rm "$name" >/dev/null 2>&1
    docker_status=""
  fi

  if [[ $docker_status == "" ]]; then
    # since we mount docker.sock and $HOME from the base system, we need to match up the
    # main user's UID and docker's GID
    local docker_gid=$(getent group docker | cut -d: -f3)
    local target_uid=$(getent passwd "$USERNAME" | cut -d: -f3)
    local docker_mount_args=""
    for mount in /var/run/docker.sock $HOME $DEVSHELL_EXTRA_MOUNTS; do
      docker_mount_args="$docker_mount_args -v $mount:$mount"
    done

    $docker run -d \
      $docker_mount_args \
      -h "${HOST%%.*}-ds-${instance}" \
      --name "$name" \
      --network=host \
      --rm \
      -e "DEVSHELL=$instance" \
      $docker_mount_args \
      "${DEVSHELL_IMAGE:-${USER}/devshell}" -d "$docker_gid" -u "$target_uid" #>/dev/null
  fi

  $docker exec -it "$name" /bin/attach
  rc=$?
  return $rc
}
