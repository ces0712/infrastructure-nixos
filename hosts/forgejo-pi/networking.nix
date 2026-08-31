{config, ...}: {
  # ============================================================
  # Services (tailscale, openssh, fail2ban)
  # ============================================================
  services = {
    tailscale = {
      enable = true;
      openFirewall = true;
      authKeyFile = config.sops.secrets."tailscale/auth_key".path;
      useRoutingFeatures = "server";
      # TODO: remove "--accept-dns=false" and the
      # networking.nameservers block in hosts/forgejo-pi/hardware.nix once
      # the Tailscale Linux MagicDNS regression (introduced in 1.98.1) is
      # fully fixed upstream.
      extraUpFlags = [
        "--accept-dns=false"
        "--accept-routes"
        "--hostname=forgejo-pi"
      ];
    };

    openssh = {
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

    fail2ban = {
      enable = true;
      maxretry = 5;
      bantime = "1h";
      jails.sshd.settings = {
        enabled = true;
        port = "22";
        filter = "sshd";
        maxretry = 3;
      };
    };
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

  environment.etc."fail2ban/filter.d/forgejo.conf".text = ''
    [Definition]
    failregex = .* Failed authentication attempt for .* from <HOST>
    ignoreregex =
  '';

  systemd.services.tailscale-serve-forgejo = {
    description = "Expose Forgejo and Invidious over Tailscale Serve";
    after = [
      "forgejo.service"
      "invidious.service"
      "tailscaled.service"
      "network-online.target"
    ];
    wants = [
      "forgejo.service"
      "invidious.service"
      "tailscaled.service"
      "network-online.target"
    ];
    wantedBy = ["multi-user.target"];
    script = ''
      ${config.services.tailscale.package}/bin/tailscale serve --bg --https=443 127.0.0.1:3000
      ${config.services.tailscale.package}/bin/tailscale serve --bg --https=${toString config.forgejo-pi.invidiousExternalPort} ${config.services.invidious.address}:${toString config.services.invidious.port}
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "10s";
      ExecStop = "${config.services.tailscale.package}/bin/tailscale serve reset";
    };
  };

  # ============================================================
  # Sudo
  # ============================================================
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };
}
