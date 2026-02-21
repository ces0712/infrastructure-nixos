{config, ...}: {
  # ============================================================
  # Tailscale
  # ============================================================
  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = config.sops.secrets."tailscale/auth_key".path;
    useRoutingFeatures = "server";
    extraUpFlags = [
      "--accept-dns"
      "--accept-routes"
      "--hostname=forgejo-pi"
    ];
  };

  # ============================================================
  # Firewall
  # ============================================================
  networking.firewall = {
    enable = true;
    logRefusedConnections = true;
    allowedUDPPorts = [41641];
    trustedInterfaces = ["tailscale0"];
  };

  # ============================================================
  # OpenSSH hardening
  # ============================================================
  services.openssh = {
    enable = true;
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      ListenAddress = "0.0.0.0";
      KexAlgorithms = [
        "curve25519-sha256"
        "curve25519-sha256@libssh.org"
        "diffie-hellman-group16-sha512"
        "diffie-hellman-group18-sha512"
      ];
      Ciphers = [
        "chacha20-poly1305@openssh.com"
        "aes256-gcm@openssh.com"
        "aes128-gcm@openssh.com"
      ];
      Macs = [
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256-etm@openssh.com"
        "umac-128-etm@openssh.com"
      ];
      LogLevel = "VERBOSE";
    };
  };

  # ============================================================
  # fail2ban
  # ============================================================
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "1h";
    bantime-increment = {
      enable = true;
      multiplier = "1 2 4 8 16 32 64";
      maxtime = "168h";
    };
    jails.sshd.settings = {
      enabled = true;
      port = "22";
      filter = "sshd";
      maxretry = 3;
    };
  };

  environment.etc."fail2ban/filter.d/forgejo.conf".text = ''
    [Definition]
    failregex = .* Failed authentication attempt for .* from <HOST>
    ignoreregex =
  '';

  # ============================================================
  # Sudo
  # ============================================================
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };
}
