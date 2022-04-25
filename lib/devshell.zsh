: ${DEVSHELL_IMAGE:=${USER}-devshell}

_devshell_name="$USER-devshell"
_devshell_docker="$DEVSHELL_DOCKER_SUDO docker"

dev() {

  # don't allow running this from inside a devshell for now
  if [[ "$DEVSHELL" == "1" ]]; then
    echo "dev: cannot run from inside a devshell" >&2
    return 1
  fi

  # -f to force repave
  if [[ $1 == "-f" ]]; then
    $_devshell_docker stop "$_devshell_name" 2>/dev/null
    $_devshell_docker rm "$_devshell_name" 2>/dev/null
  fi

  local docker_status=$(docker inspect -f '{{ .State.Status }}' "$_devshell_name" 2>/dev/null)
  if [[ $docker_status == "stopped" || $docker_status == "exited" ]]; then
    $_devshell_docker start "$_devshell_name"
  elif [[ $docker_status == "" ]]; then
    local docker_host="$(hostname -s)-ds"

    # since we mount docker.sock and $HOME from the base system, we need to match up the
    # main user's UID and docker's GID
    local docker_gid=$(getent group docker | cut -d: -f3)
    local target_uid=$(getent passwd "$USERNAME" | cut -d: -f3)

    if [[ -n "$docker_gid" ]]; then
      local docker_gid_arg="-d $docker_gid"
    fi

    local docker_mount_args=""
    for mount in /home $DEVSHELL_EXTRA_MOUNTS; do
      docker_mount_args="$docker_mount_args -v $mount:$mount"
    done

    set -x
    $_devshell_docker run -d \
      -v /var/run/docker.sock:/var/run/docker.sock \
      $docker_mount_args \
      -h "$docker_host" \
      --name "$_devshell_name" \
      "$DEVSHELL_IMAGE" $docker_gid_arg -u $target_uid
  fi

  # TODO: wait/poll State.Status until it's running, and tmux is active
  $_devshell_docker exec -it "$_devshell_name" /bin/attach
}
