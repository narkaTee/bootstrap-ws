#!/usr/bin/env bash

install_disk="$1"
if [ -z "$install_disk" ]; then
    >&2 echo "Missing target disk"
    exit 1
fi

packages=(base linux linux-firmware vim networkmanager gnome gnome-extra grub)

set -xeo pipefail
loadkeys de-latin1

efimode="$(test -d /sys/firmware/efi/efivars && echo yes || echo no)"
# check time?
#timedatectl

if [ "$efimode" == "yes" ]; then
    echo "not implemented yet"
    exit 1
else
    parted -sa optimal "$install_disk" mklabel gpt
    # boot
    parted -sa optimal "$install_disk" mkpart primary 0% 1GB
    # swap
    parted -sa optimal "$install_disk" mkpart primary 1GB 5GB
    # root
    parted -sa optimal "$install_disk" mkpart primary 5GB 100%
    # grub gpt boot
    parted -s "$install_disk" mkpart primary 34s 2047s
    parted -s "$install_disk" set 4 bios_grub on
fi

boot="${install_disk}1"
swap="${install_disk}2"
root="${install_disk}3"

mkfs.btrfs -f "$boot"
mkswap "$swap"
mkfs.btrfs -f "$root"

mount "$root" /mnt
mount --mkdir "$boot" /mnt/boot
swapon "$swap"

reflector -c de --delay 1 -f 5 > /etc/pacman.d/mirrorlist

pacstrap -K /mnt "${packages[@]}"

genfstab -U /mnt >> /mnt/etc/fstab

chroot="arch-chroot /mnt"
$chroot ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
$chroot hwclock --systohc
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /mnt/etc/locale.gen
$chroot locale-gen
echo "LANG=en_US.UTF-8" | tee /mnt/etc/locale.conf
echo "KEYMAP=de-latin1" | tee /mnt/etc/vconsole.conf
echo "arch" | tee /mnt/etc/hostname
$chroot passwd

$chroot grub-install "$install_disk"
$chroot grub-mkconfig -o /boot/grub/grub.cfg

$chroot systemctl enable NetworkManager
$chroot systemctl enable gdm

umount /mnt/boot /boot

echo "ready to boot into new system"
