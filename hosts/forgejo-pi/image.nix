{...}: {
  # Keep image simple and bootable; grow root fs on first boot.
  sdImage = {
    compressImage = false;
    populateRootCommands = "";
    expandOnBoot = true;
  };
}
