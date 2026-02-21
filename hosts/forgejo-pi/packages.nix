{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # system utilities
    vim
    htop
    tmux
    git
    # network
    curl
    dnsutils
    traceroute
    tailscale
    # disk utilities
    parted
    smartmontools
    # nix tools
    nix-tree
    nvd
    # db
    sqlite # used by forgejo-wal and backup
    restic # used by backup
    rclone # used by backup
  ];
}
