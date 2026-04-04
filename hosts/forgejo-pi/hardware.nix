{
  config,
  lib,
  pkgs,
  ...
}: {
  # ============================================================
  # Kernel
  # ============================================================
  boot = {
    kernelPackages = pkgs.${config.forgejo-pi.kernelPackages};

    kernelParams = [
      "console=tty1"
      "console=ttyAMA0,115200n8"
      "rootwait"
      "rootdelay=10"
      "loglevel=7"
      "systemd.log_level=debug"
      "systemd.log_target=console"
      "rd.udev.log_level=debug"
      "rd.systemd.show_status=true"
    ];

    consoleLogLevel = 7;

    kernelModules = [
      "bcm2835_wdt"
    ];

    initrd = {
      systemd.enable = true;
      systemd.emergencyAccess = true;
      verbose = true;
      availableKernelModules = [
        "xhci_pci"
        "uas"
        "sd_mod"
        "usb_storage"
        "usbhid"
      ];
    };

    # Forgejo node is wired; disable Bluetooth stack/modules.
    blacklistedKernelModules = [
      "bluetooth"
      "btusb"
      "hci_uart"
      "btbcm"
      "btqca"
      "btsdio"
      "btintel"
      "btrtl"
    ];

    # ============================================================
    # Boot loader
    # ============================================================
    loader = {
      grub.enable = false;
      generic-extlinux-compatible = {
        enable = true;
        configurationLimit = 1; # keep a single boot entry to avoid stale sd-card fallbacks
      };
      timeout = 3;
    };

    # ============================================================
    # IP forwarding for Tailscale
    # ============================================================
    kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
      "net.ipv4.conf.all.rp_filter" = 0;
      "net.ipv4.conf.default.rp_filter" = 0;
    };
  };

  # ============================================================
  # Firmware + Hardware
  # ============================================================
  hardware = {
    enableRedistributableFirmware = true;
    bluetooth = {
      enable = false;
      powerOnBoot = false;
    };
  };

  # Prevent userspace BT stack from starting.
  systemd.services.bluetooth.enable = false;
  systemd.services.hciuart.enable = false;

  # ============================================================
  # Reset module - clean RPi4 reboot behavior
  # ============================================================
  # imported via nixpkgs modules automatically

  # ============================================================
  # Swap - zram primary, swapfile fallback
  # ============================================================
  # Avoid boot blocking on USB swap partition discovery timing.
  swapDevices = lib.mkForce [];

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50; # 4GB de los 8GB
  };

  # ============================================================
  # Periodic SSD TRIM
  # ============================================================
  services.fstrim = {
    enable = true;
    interval = "weekly";
  };

  # ============================================================
  # Thermal management
  # ============================================================
  systemd.services.rpi-thermal = {
    description = "RPi4 thermal management";
    wantedBy = ["multi-user.target"];
    script = ''
      echo 80000 > /sys/class/thermal/thermal_zone0/trip_point_0_temp || true
    '';
    serviceConfig.Type = "oneshot";
  };

  # ============================================================
  # Journald - persistent, limited to protect SSD
  # ============================================================
  services.journald.extraConfig = ''
    Storage=persistent
    Compress=yes
    SystemMaxUse=500M
    SystemKeepFree=1G
    MaxRetentionSec=1week
  '';

  # ============================================================
  # Nix - GC + optimise + limit build resources
  # ============================================================
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
    optimise = {
      automatic = true;
      dates = ["weekly"];
    };
    settings = {
      max-jobs = 2;
      cores = 2;
      auto-optimise-store = true;
      trusted-users = ["root" "nixos"];
      allowed-users = ["root" "nixos"];
    };
  };

  # ============================================================
  # Watchdog
  # ============================================================
  systemd.settings.Manager = {
    RuntimeWatchdogSec = "30s";
    RebootWatchdogSec = "10min";
  };
}
