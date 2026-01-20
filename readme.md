# laptop setup

```
sudo apt install ansible -y
git clone https://github.com/narkaTee/bootstrap-ws.git
cd bootstrap-ws
# you should check what secret settings you want to make
vim inventory/group_vars/laptop.yaml
./setup-laptop.sh
```

## SSH Config

The runbook sets up a `~/.ssh/config.d/` folder where configurations can be dropped

To put a `additional-config.conf` into that folder edit `inventory/group_vars/laptop.yaml`

```
ssh_additional_config:
  - |
    Host my-trusted-host
        User user
        ForwardAgent yes
  - |
    Host another-host
        User anotheruser
```

## yubikey

* pam auth with yubikey
  * https://github.com/Yubico/pam-u2f

Too enable this make sure `inventory/group_vars/laptop.yaml` contains:

```
yubikey_pam_keys:
  - user: <username>
    keylines:
      - "..."
      - "..."
```

each yubikey must be added with a keyline. The line can be obtained by running: `pamu2fcfg -u<username>`

## dracut

drop to shell kernel param: `rd.break=initqueue`

dracut is still experimental in debian.

It requires some manual fixes for plymouth and disk decryption to work (see [`dracut`](dracut/)).

The plan is to use it later with systemd-cryptsetup and fido2 unlock.
But this has to wait until the dracut setup proved to be reliable.

Ressources:

- https://github.com/dracutdevs/dracut/issues/996
- https://gitlab.freedesktop.org/plymouth/plymouth/-/issues/116
- https://github.com/adi1090x/plymouth-themes/issues/10

fido unlock

- https://www.guyrutenberg.com/2022/02/17/unlock-luks-volume-with-a-yubikey/
- https://fedoramagazine.org/use-systemd-cryptenroll-with-fido-u2f-or-tpm2-to-decrypt-your-disk/

enroll: `sudo systemd-cryptenroll /dev/nvme0n1pX --fido2-device=auto  --fido2-with-client-pin=yes`
crypttab: `fido2-device=auto`
dracut fido:

```
## Spaces in the quotes are critical.
# install_optional_items+=" /usr/lib/x86_64-linux-gnu/libfido2.so.* "

## Ugly workround because the line above doesn't fetch
## dependencies of libfido2.so
install_items+=" /usr/bin/fido2-token "

# Required detecting the fido2 key
install_items+=" /usr/lib/udev/rules.d/60-fido-id.rules /usr/lib/udev/fido_id "
```

# Sandbox builds

## Sanbox container

To test the build locally: `podman build -t sandbox:latest -f ./sandbox/Dockerfile .`

## KVM/qemu image

To test the build locally just run: `./sandbox/kvm-sandbox-build.sh`
The script will not work properly if run from the wrong working dir

# pen test botstrapping

# arch base install

1. `git clone https://github.com/narkatee/workstation`
2. `./install-arch.sh`
3. reboot 🚀😎

# setup blackarch

1. arch base install
2. login as root
3. `cd ansible`
4. `./setup.sh blackarch.yml`

# setup pen test tooling

distro independant

1. base install (arch or kali)
2. login as root
3. `cd ansible`
4. `./setup.sh tooling.yml`
