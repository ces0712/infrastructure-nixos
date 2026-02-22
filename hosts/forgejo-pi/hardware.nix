{
  config,
  pkgs,
  ...
}: {
  # ============================================================
  # Kernel
  # ============================================================
  boot = {
    kernelPackages = pkgs.${config.forgejo-pi.kernelPackages};

    kernelParams = [
      "cma=64M"
      "console=ttyS0,115200n8"
      "console=tty1"
    ];

    kernelModules = [
      "vc4"
      "i2c_dev"
      "bcm2835_wdt"
    ];

    initrd.availableKernelModules = [
      "xhci_pci"
      "usbhid"
      "usb_storage"
      "vc4"
    ];

    # ============================================================
    # Boot loader
    # ============================================================
    loader = {
      grub.enable = false;
      generic-extlinux-compatible = {
        enable = true;
        configurationLimit = 5; # limit generations /boot
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
    graphics = {
      enable = true; # VideoCore IV
    };
  };

  # ============================================================
  # Reset module - clean RPi4 reboot behavior
  # ============================================================
  # imported via nixpkgs modules automatically

  # ============================================================
  # Swap - zram primary, swapfile fallback
  # ============================================================
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
    };
  };

  # ============================================================
  # Watchdog
  # ============================================================
  systemd.extraConfig = ''
    RuntimeWatchdogSec=30s
    RebootWatchdogSec=10min
  '';
}
