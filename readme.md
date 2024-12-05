# laptop setup

## yubikey

* pam auth with yubikey
  * https://github.com/Yubico/pam-u2f

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
