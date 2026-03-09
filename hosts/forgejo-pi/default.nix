{secrets, ...}: {
  environment.etc."forgejo-pi-profile".text = "runtime";

  networking = {
    hostName = "forgejo-pi";
    domain = "tail8f7f61.ts.net";
    timeServers = [
      "time.cloudflare.com"
      "time.google.com"
      "pool.ntp.org"
    ];
  };

  time.timeZone = "America/Montevideo";
  i18n.defaultLocale = "en_US.UTF-8";
  system.stateVersion = "25.05";

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

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = [
      (builtins.readFile "${secrets}/ssh-hosts/admin.pub")
    ];
  };
}
