{secrets, ...}: {
  sops = {
    age = {
      # Stable decryption key copied by deploy/bootstrap tooling from local pass/key file.
      keyFile = "/var/lib/sops-nix/key.txt";
      # Keep host-key import as fallback when available.
      sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
      generateKey = false;
    };
    defaultSopsFile = "${secrets}/secrets/forgejo.yaml";
  };
}
