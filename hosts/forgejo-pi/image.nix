{config, ...}: {
  # Shared bootstrap image flashed to both SD and SSD. Keep labels stable and
  # leave spare SSD capacity for the remote partitioning step.
  sdImage = {
    compressImage = false;
    populateRootCommands = "";
    expandOnBoot = false;
    firmwareSize = config.forgejo-pi.image.firmwareSizeMiB;
  };
}
