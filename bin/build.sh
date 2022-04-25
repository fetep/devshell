#!/usr/bin/env bash
# build out a development environment

set -e

bin_dir=$(dirname $0)
declare -A versions

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

install_other() {
  local tmpd="$(mktemp -d)"
  trap "rm -rf \"$tmpd\"" EXIT
  cd $tmpd
  curl -sLO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  sudo install -m 0755 minikube-linux-amd64 /usr/local/bin/minikube
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
user_setup
cleanup
