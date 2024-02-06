# https://status.nixos.org/

let
  lib = import (fetchTarball "channel:nixos-23.11" + "/lib");
  # grab SHA from https://status.nixos.org/
  pkgs = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/25e3d4c0d3591c99929b1ec07883177f6ea70c9d.tar.gz") {};

  pkgs_base = with pkgs; [
    bash
    binutils
    bzip2
    cacert
    coreutils-full
    cowsay
    curl
    dig
    figlet
    findutils
    flock
    fping
    getent
    gnugrep
    gnutar
    gzip
    inetutils
    less
    lsb-release
    lsof
    man
    mtr
    neovim
    nix
    nmap
    openssh
    openssl
    procps
    pwgen
    rsync
    shadow
    strace
    sudo
    tmux
    unzip
    wget
    zip
    zsh
  ];

  pkgs_cloud = with pkgs; [
    argocd
    aws-nuke
    awscli2
    docker
    docker-compose
    k9s
    kubectl
    kubernetes-helm
    kustomize
    localstack
    packer
    terraform
    terragrunt
    vault
  ];

  pkgs_dev = with pkgs; [
    ack
    autoconf269
    automake115x
    bazel
    cargo
    ctags
    fpm
    gcc
    gh
    git
    gnumake
    go
    jq
    mongosh
    nodejs
    python3
    python311Packages.pip
    ripgrep
    shellcheck
    tmux
    wget
    yq
  ];

  pkgs_all = pkgs_base ++ pkgs_cloud ++ pkgs_dev;

  home = "/home/petef";
  shell = "/bin/zsh";
  user = "petef";

  devshell_base = pkgs.stdenv.mkDerivation {
    name = "devshell_base";
    src = lib.fileset.toSource {
      root = ./.;
      fileset = ./bin;
    };
    postInstall = ''
      mkdir -p $out/bin
      cp -v ./bin/attach.sh $out/bin/attach
      cp -v ./bin/init.sh $out/bin/init
    '';
  };
in
{
  devshell = pkgs.dockerTools.buildImage {
    name = "devshell-${user}";
    tag = "latest";

    config = {
      Entrypoint = [
        "/bin/init"
      ];
      Env = [
        "HOME=${home}"
        "SHELL=${shell}"
        "USER=${user}"
        "USERNAME=${user}"
      ];
      User = "${user}:${user}";
      Volumes = {
        "${home}" = {};
        "/var/run/docker.sock" = {};
      };
      WorkingDir = "${home}";
    };

    copyToRoot = pkgs.buildEnv {
      name = "root";
      paths = pkgs_all ++ [devshell_base];
      pathsToLink = [
        "/bin"
      ];
    };

    runAsRoot = ''
#!${pkgs.runtimeShell}
set -xeuo pipefail

# setup user, group docker + sudo
${pkgs.dockerTools.shadowSetup}
groupadd -r docker
useradd -U -G docker,root -s "${shell}" "${user}"
echo '${user} ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers

# for some reason, /tmp defaults to 0755
chmod 1777 /tmp

# fix cert bundle so openssl works
mkdir -p -m 0755 /etc/ssl/certs
ln -s ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt

# when pkgs.sudo ends in a docker image, it's not setuid
mv /bin/sudo /bin/sudo.link
install -c -m 4755 "$(readlink /bin/sudo.link)" /bin/sudo
'';
  };
}
