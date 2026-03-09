{secrets, ...}: {
  networking = {
    hostName = "forgejo-pi";
    domain = "tail8f7f61.ts.net";
  };

  time.timeZone = "America/Montevideo";
  i18n.defaultLocale = "en_US.UTF-8";
  system.stateVersion = "25.05";

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = [
      (builtins.readFile "${secrets}/ssh-hosts/admin.pub")
    ];
  };
}
