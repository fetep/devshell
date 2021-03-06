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
  if [[ $ver == "" ]]; then
    echo "build: $pkg: no version specified" >&2
    exit 2
  fi

  echo $ver
}

base_setup() {
  install -m 0755 $bin_dir/attach.sh /bin/attach
  install -m 0755 $bin_dir/init.sh /sbin/init.devshell
  echo "%wheel ALL=(ALL) NOPASSWD: ALL" >/etc/sudoers.d/devshell

  sed -i -e '/^tsflags=nodocs/d' /etc/dnf/dnf.conf
  echo "fastestmirror=1" >>/etc/dnf/dnf.conf
  dnf -qy update
  dnf -qy install dnf-plugins-core

  # extra repos + keys
  dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
  dnf config-manager --add-repo https://packages.cloud.google.com/yum/repos/cloud-sdk-el7-x86_64
  dnf config-manager --add-repo https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
  dnf config-manager --add-repo https://repo.mongodb.org/yum/redhat/7/mongodb-org/5.0/x86_64
  dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
  dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo

  dnf -qy copr enable dioni21/compat-openssl10

  rpm --import https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
  rpm --import https://packages.cloud.google.com/yum/doc/yum-key.gpg
  rpm --import https://www.mongodb.org/static/pgp/server-5.0.asc

  rpm -i http://yum.puppet.com/puppet-release-fedora-34.noarch.rpm
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
  export GOROOT=/usr/local/go
  export GOPATH="$tmpd/go"
  mkdir -p "$GOPATH"

  go install github.com/fetep/xapply@latest
  mv $GOPATH/bin/xapply /usr/local/bin
}

install_other() {
  curl -sL -o /usr/local/bin/minikube \
    https://storage.googleapis.com/minikube/releases/v$(_version minikube)/minikube-linux-amd64
  chmod 0755 /usr/local/bin/minikube

  flux_ver=$(_version flux)
  curl -sL -o "$tmpd/flux.tar.gz" \
    https://github.com/fluxcd/flux2/releases/download/v${flux_ver}/flux_${flux_ver}_linux_amd64.tar.gz
  tar -C /usr/local/bin -xvzf "$tmpd/flux.tar.gz"

  curl -sL -o "$tmpd/awscli.zip" https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
  (cd "$tmpd" && unzip awscli.zip && cd aws && ./install)

  helm_ver=$(_version helm)
  curl -sL -o "$tmpd/helm.tar.gz" https://get.helm.sh/helm-v${helm_ver}-linux-amd64.tar.gz
  (cd "$tmpd" && tar xzf helm.tar.gz && install -c -m 755 linux-amd64/helm /usr/local/bin/helm)

  kust_ver=$(_version kustomize)
  curl -sL -o "$tmpd/kust.tar.gz" \
    https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${kust_ver}/kustomize_v${kust_ver}_linux_amd64.tar.gz
  (cd "$tmpd" && tar xzf kust.tar.gz && install -c -m 755 kustomize /usr/local/bin/kustomize)

  kuev_ver=$(_version kubeval)
  curl -sL -o "$tmpd/kuev.tar.gz" \
    https://github.com/instrumenta/kubeval/releases/download/v${kuev_ver}/kubeval-linux-amd64.tar.gz
  (cd "$tmpd" && tar xzf kuev.tar.gz && install -c -m 755 kubeval /usr/local/bin/kubeval)

  bazel_ver=$(_version bazel)
  curl -sL -o "$tmpd/bazel" \
    https://github.com/bazelbuild/bazel/releases/download/${bazel_ver}/bazel-${bazel_ver}-linux-x86_64
  install -c -m 755 "$tmpd/bazel" /usr/local/bin/bazel

  node_ver=$(_version nodejs)
  curl -sL -o "$tmpd/node.tar.xz" \
    https://nodejs.org/dist/v${node_ver}/node-v${node_ver}-linux-x64.tar.xz
  (cd "$tmpd" && tar xf node.tar.xz)
  mv "$tmpd/node-v${node_ver}-linux-x64" /usr/local/node

  curl -sL -o "$tmpd/bazel" \
    https://github.com/bazelbuild/bazel/releases/download/${bazel_ver}/bazel-${bazel_ver}-linux-x86_64
  install -c -m 755 "$tmpd/bazel" /usr/local/bin/bazel

  pip3 install yq
}

install_rpms() {
  PACKAGES="
    ack
    ansible
    autoconf
    automake
    bind-utils
    bzip2
    cloc
    compat-openssl10
    cowsay
    ctags
    docker-ce-cli
    docker-compose-plugin
    figlet
    fping
    gettext-devel
    gcc
    gcc-c++
    gh
    git
    google-cloud-cli
    jansson-devel
    jq
    jwhois
    kubeadm-$(_version kubeadm)
    kubectl-$(_version kubectl)
    less
    libseccomp-devel
    libtool
    libxml2-devel
    libyaml-devel
    links
    lsof
    make
    man-pages
    mongodb-database-tools
    mongodb-mongosh
    mongodb-org-shell
    mtr
    net-tools
    nmap
    nmap-ncat
    packer-$(_version packer)
    pcre2-devel
    puppet-agent
    pwgen
    python3-pip
    redhat-lsb-core
    rsync
    strace
    tcpdump
    telnet
    terraform-$(_version terraform)
    traceroute
    tmux
    unzip
    vault-$(_version vault)
    vim-enhanced
    vim-pathogen
    wget
    zip
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
