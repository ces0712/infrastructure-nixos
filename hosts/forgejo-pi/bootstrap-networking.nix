{
  lib,
  pkgs,
  secrets,
  ...
}: let
  initrdHostKeyPath = "/etc/ssh/initrd_ssh_host_ed25519_key";
  initrdAuthorizedKeysPath = "/etc/ssh/authorized_keys.d/root";
  initrdSshConfigPath = "/etc/ssh/sshd_config";
in {
  networking.useDHCP = lib.mkDefault true;

  boot.initrd = {
    network.enable = true;

    systemd = {
      network.enable = true;

      users = {
        root.shell = "/bin/bash";
        sshd = {
          uid = 1;
          group = "sshd";
        };
      };

      groups.sshd.gid = 1;

      contents = {
        "${initrdAuthorizedKeysPath}".text = builtins.readFile "${secrets}/ssh-hosts/admin.pub";
        "${initrdSshConfigPath}".text = ''
          UsePAM no
          Port 22
          PasswordAuthentication no
          KbdInteractiveAuthentication no
          ChallengeResponseAuthentication no
          PermitRootLogin prohibit-password
          AuthorizedKeysFile %h/.ssh/authorized_keys %h/.ssh/authorized_keys2 ${initrdAuthorizedKeysPath}
          HostKey ${initrdHostKeyPath}
          UseDNS no
          LogLevel VERBOSE
        '';
      };

      storePaths = [
        "${pkgs.openssh}/bin/sshd"
        "${pkgs.openssh}/libexec/sshd-auth"
        "${pkgs.openssh}/libexec/sshd-session"
      ];

      services.sshd = {
        description = "Initrd SSH Daemon";
        wantedBy = ["initrd.target"];
        wants = ["network-online.target"];
        after = [
          "network-online.target"
        ];
        before = ["shutdown.target"];
        conflicts = ["shutdown.target"];
        unitConfig.DefaultDependencies = false;
        preStart = ''
          if ! [ -e ${initrdHostKeyPath} ]; then
            ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -f ${initrdHostKeyPath}
          fi
          /bin/chmod 0600 ${initrdHostKeyPath}
        '';
        serviceConfig = {
          ExecStart = "${pkgs.openssh}/bin/sshd -D -e -f ${initrdSshConfigPath}";
          Type = "simple";
          KillMode = "process";
          Restart = "on-failure";
        };
      };
    };
  };

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
      PermitRootLogin = lib.mkForce "prohibit-password";
      ListenAddress = "0.0.0.0";
      LogLevel = "VERBOSE";
    };
  };

  networking.firewall = {
    enable = true;
    logRefusedConnections = true;
    allowedTCPPorts = [22];
  };
}
