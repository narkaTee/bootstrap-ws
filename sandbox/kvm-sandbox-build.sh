#!/usr/bin/env bash
set -euo pipefail

IMG_CACHE="./sandbox/cache"
BASE_IMG="$IMG_CACHE/debian-13-nocloud-amd64.qcow2"
CUSTOM_IMG="$IMG_CACHE/debian-13-nocloud-amd64-custom.qcow2"
VERBOSE="${VERBOSE:-0}"

conditional_download_checksums() {
  curl -s -o "$IMG_CACHE/SHA512SUMS" \
    -z "$IMG_CACHE/SHA512SUMS" https://cloud.debian.org/images/cloud/trixie/latest/SHA512SUMS
}

checksum_matches() {
  expected_sha=$(grep 'debian-13-nocloud-amd64.qcow2' "$IMG_CACHE/SHA512SUMS" | awk '{print $1}')
  actual_sha=$(sha512sum "$BASE_IMG" | awk '{print $1}')
  if [ "$expected_sha" != "$actual_sha" ]; then
      return 1
  fi
  return 0
}

download_img() {
  curl -L -o "$BASE_IMG" https://cloud.debian.org/images/cloud/trixie/latest/debian-13-nocloud-amd64.qcow2
  if ! checksum_matches; then
    echo "Error: SHA512 checksum mismatch after re-download. Exiting."
    exit 1
  fi
}

customize_img() {
  if [ -f "$CUSTOM_IMG" ]; then
    echo "Customized image already exists. Skipping customization."
    return
  fi

  echo "Creating 20GB qcow2 image..."
  qemu-img create -f qcow2 -o preallocation=metadata "$CUSTOM_IMG" 20G

  echo "Resizing base image to 20GB..."
  virt-resize --expand /dev/sda1 --output-format qcow2 "$BASE_IMG" "$CUSTOM_IMG"

  echo "Customizing image with Ansible and configuration..."
  virt-customize -v -a "$CUSTOM_IMG" \
    --run-command "mkdir -p /root/ansible" \
    --copy-in ansible.cfg:/root/ansible/ \
    --copy-in requirements.yaml:/root/ansible/ \
    --copy-in roles:/root/ansible/ \
    --copy-in sandbox/sandbox.yaml:/root/ansible/ \
    --copy-in sandbox/inventory:/root/ansible/ \
    --run sandbox/kvm-sandbox-customize.sh \
    --copy-in sandbox/pre-warm-tools.sh:/tmp/ \
    --run-command "sudo -u dev /tmp/pre-warm-tools.sh" \
    --run-command "rm /tmp/pre-warm-tools.sh" \
    --run-command "apt-get --yes autopurge" \
    --run-command "apt-get --yes clean autoclean" \
    --run-command "rm -rf /var/lib/apt/lists/*"

  echo "Sparsifying image to reclaim unused space..."
  virt-sparsify --in-place --format qcow2 "$CUSTOM_IMG"

  echo "Build complete. Final image size:"
  qemu-img info "$CUSTOM_IMG" | grep -E "virtual size|disk size"
}

mkdir -p "$IMG_CACHE"
conditional_download_checksums

if [ ! -f "$BASE_IMG" ]; then
  download_img
elif ! checksum_matches; then
  echo "SHA512 checksum mismatch. Re-downloading the image."
  rm "$BASE_IMG"
  download_img
else
  echo "SHA512 Checksum still up to date. Using cached image."
fi

customize_img
