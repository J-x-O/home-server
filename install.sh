#!/usr/bin/env bash
# Installs this flake onto a fresh machine from the NixOS installer ISO.
#
#   sudo -i
#   bash <(curl -sL https://raw.githubusercontent.com/J-x-O/home-server/main/install.sh)
#
# Wipes the chosen disk, partitions it (1 GiB EFI + ext4 root), generates the
# hardware config into the cloned repo and runs nixos-install.
set -euo pipefail

REPO="${REPO:-https://github.com/J-x-O/home-server.git}"
HOST="${HOST:-homeserver}"
USERNAME="${USERNAME:-jesco}"
TARGET=/mnt/etc/nixos

die() { echo "error: $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "run as root (sudo -i first)"
[[ -d /sys/firmware/efi ]] || die "not booted in UEFI mode"
ping -c 1 -W 5 github.com > /dev/null || die "no internet connection"

export NIX_CONFIG="experimental-features = nix-command flakes"
command -v git > /dev/null || PATH="$(nix-build '<nixpkgs>' -A git --no-out-link)/bin:$PATH"

echo
lsblk -d -e 7 -o NAME,SIZE,TRAN,MODEL
echo
read -rp "Disk to install to (e.g. sda, nvme0n1): " name
DISK="/dev/$name"
[[ -b $DISK ]] || die "$DISK is not a block device"
read -rp "ALL DATA ON $DISK WILL BE ERASED. Type 'yes' to continue: " confirm
[[ $confirm == yes ]] || die "aborted"

# nvme0n1 -> nvme0n1p1, sda -> sda1
part() { if [[ $DISK =~ [0-9]$ ]]; then echo "${DISK}p$1"; else echo "${DISK}$1"; fi; }

echo ">> Partitioning $DISK"
umount -R /mnt 2> /dev/null || true
wipefs -af "$DISK"
parted -s "$DISK" -- \
  mklabel gpt \
  mkpart ESP fat32 1MiB 1GiB \
  set 1 esp on \
  mkpart root ext4 1GiB 100%
udevadm settle
mkfs.fat -F 32 -n boot "$(part 1)"
mkfs.ext4 -F -L nixos "$(part 2)"
udevadm settle

echo ">> Mounting"
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount -o umask=077 /dev/disk/by-label/boot /mnt/boot

echo ">> Cloning $REPO"
git clone "$REPO" "$TARGET"

echo ">> Generating hardware config"
nixos-generate-config --root /mnt --show-hardware-config \
  > "$TARGET/hosts/$HOST/hardware-configuration.nix"
# Flakes only see tracked files.
git -C "$TARGET" add "hosts/$HOST/hardware-configuration.nix"

echo ">> Installing"
nixos-install --flake "$TARGET#$HOST" --no-root-passwd

echo ">> Set a password for $USERNAME (console login; SSH stays key-only)"
until nixos-enter --root /mnt -c "passwd $USERNAME"; do :; done

cat << EOF

Done. Next:
  1. reboot, pull the USB stick, log in as $USERNAME
  2. nmtui  -> join your Wi-Fi
  3. on your desktop, copy the hardware config into the repo and commit it:
     scp $USERNAME@<ip>:/etc/nixos/hosts/$HOST/hardware-configuration.nix hosts/$HOST/
EOF
