# PLACEHOLDER: install.sh overwrites this with systemd-boot (UEFI) or GRUB (legacy BIOS).
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
