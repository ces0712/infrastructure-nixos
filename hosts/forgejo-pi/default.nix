{
  environment.etc."forgejo-pi-profile".text = "runtime";

  networking = {
    timeServers = [
      "time.cloudflare.com"
      "time.google.com"
      "pool.ntp.org"
    ];
  };

  services.timesyncd = {
    enable = true;
    servers = [
      "time.cloudflare.com"
      "time.google.com"
      "pool.ntp.org"
    ];
    fallbackServers = [
      "0.nixos.pool.ntp.org"
      "1.nixos.pool.ntp.org"
    ];
  };
}
