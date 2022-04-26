# devshell

`devshell` is a Docker image containing my preferred development environment
(which happens to be text-based).

On start, a `dev` tmux session is created. When the tmux session ends, so does
the docker container.

[lib/devshell.zsh](https://github.com/fetep/devshell/blob/master/lib/devshell.zsh)
contains a zsh function `dev`. This handles starting the container, and
attaching to the tmux session inside of it. All terminal features seem to work
well inside of `docker run -it` - including 256 color support and [bracketed
paste mode](https://cirw.in/blog/bracketed-paste).

## Build

Starting with a barebones Fedora docker image,
[bin/build.sh](https://github.com/fetep/devshell/blob/master/bin/build.sh)
installs everything I use for day to day dev work.

Versions are pinned in
[lib/versions](https://github.com/fetep/devshell/blob/master/lib/versions).
Some code needs to be written to look for updates here (dependabot style).

## Filesystem pass through

We pass through `$HOME` (and optionally other directories, set
`$DEVSHELL_EXTRA_MOUNTS`), so this makes the dev environment ephemeral. Repave
early, repave often.

`/var/run/docker.sock` is also passed through - this enables you to still
interact with the local dockerd as part of dev activities.

Since we pass through filesystems, it's important to have matching UIDs/GIDs.
This has to happen at run-time (one docker image build may get run on multiple
hosts), so as part of starting the image we pass through our own UID and
docker's GID and set them appropriately in the container.

Since we aren't fully managing our `$HOME`, dotfiles are out of scope. To help
manage dotfiles, see my
[dotfiles](https://github.com/fetep/dotfiles) repo.

## Known Issues

* ssh-agent pass through (considering moving `$SSH_AUTH_SOCK` to be somewhere
in `$HOME`)
