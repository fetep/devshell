#!/usr/bin/env bash
# build out a development environment

set -e

bin_dir=$(dirname $0)
tmpd="$(mktemp -d)"
declare -A versions

trap "set -x; rm -rf \"$tmpd\"" EXIT

_version() {
  pkg=$1
  ver=${versions[$pkg]}
  if [[ "$ver" == "" ]]; then
    echo "build: $pkg: no version specified" >&2
    exit 2
  fi

  echo $ver
}

base_setup() {
  install -m 0755 $bin_dir/attach.sh /bin/attach
  install -m 0755 $bin_dir/init.sh /sbin/init.devshell
  echo "%wheel ALL=(ALL) NOPASSWD: ALL" >/etc/sudoers.d/devshell

  echo "fastestmirror=1" >>/etc/dnf/dnf.conf
  dnf -qy update
  dnf -qy install dnf-plugins-core

  # extra repos + keys
  dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
  dnf config-manager --add-repo https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
  dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo

  dnf -qy copr enable vbatts/bazel

  rpm --import https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
  rpm --import https://packages.cloud.google.com/yum/doc/yum-key.gpg
}

cleanup() {
  dnf clean all
}

# install golang toolchain + other go projects
install_go() {
  curl -sL -o "$tmpd/golang.tar.gz" https://go.dev/dl/go$(_version go).linux-amd64.tar.gz
  tar -C /usr/local -xzf "$tmpd/golang.tar.gz"

  # go env for binaries we need to build (no packages)
  export PATH=/usr/local/go/bin:$PATH
  export GO="$tmpd/go"
  mkdir -p "$GO"
}

install_other() {
  curl -sL -o /usr/local/bin/minikube \
    https://storage.googleapis.com/minikube/releases/v$(_version minikube)/minikube-linux-amd64
  chmod 0755 /usr/local/bin/minikube
}

install_rpms() {
  PACKAGES="
    ansible
    bazel4
    docker
    gh
    git
    kubeadm-$(_version kubeadm)
    kubectl-$(_version kubectl)
    less
    lsof
    make
    packer-$(_version packer)
    rsync
    strace
    tcpdump
    terraform-$(_version terraform)
    tmux
    vault-$(_version vault)
    vim-enhanced
    vim-pathogen
    wget
    zsh
  "

  dnf -qy group install "Minimal Install"
  dnf -qy install $PACKAGES
}

load_versions() {
  while read -r line; do
    pkg=${line%%=*}
    ver=${line##*=}
    versions[$pkg]=$ver
  done < "$bin_dir/../lib/versions"
}

user_setup() {
  useradd -U -m --groups=docker,root,wheel -s /bin/zsh petef
}

load_versions

set -x
base_setup
install_rpms
install_other
install_go
user_setup
cleanup
