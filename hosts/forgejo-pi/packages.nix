{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    vim
    htop
    tmux
    git
    curl
    dnsutils
    traceroute
    tailscale
    parted
    smartmontools
    sqlite
    restic
    rclone
    raspberrypi-eeprom
  ];
}
