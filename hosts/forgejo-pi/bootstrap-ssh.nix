{
  lib,
  secrets,
  ...
}: {
  # Shared bootstrap image only: allow root login with the admin SSH key so the
  # SD-booted system can prepare the flashed SSD without passwords.
  users.users.root.openssh.authorizedKeys.keys = [
    (builtins.readFile "${secrets}/ssh-hosts/admin.pub")
  ];

  services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";
}
