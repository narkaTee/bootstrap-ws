#!/usr/bin/env bash
set -euo pipefail

# Disable systemd-firstboot wizard
systemctl mask systemd-firstboot.service || true

# Pre-configure settings that firstboot would ask for
echo "Europe/Berlin" > /etc/timezone
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime

echo "kvm-sandbox" > /etc/hostname
hostname kvm-sandbox

apt-get update
apt-get install -y \
    podman \
    ansible \
    locales

cd /root/ansible

# we need proper locales for ansible to run
sed -i 's/^# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen --purge en_US.UTF-8
update-locale LANG=en_US.UTF-8
dpkg-reconfigure --frontend noninteractive locales
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
ansible-galaxy collection install -r requirements.yaml
ansible-playbook -e dev_sandbox_enable_sudo=true sandbox.yaml
cd ..
rm -rf /root/ansible

# autologin on serial console for dev user
mkdir -p /etc/systemd/system/serial-getty@ttyS0.service.d
cat > /etc/systemd/system/serial-getty@ttyS0.service.d/override.conf << 'EOF'
[Unit]
Description=Serial Getty on ttyS0 - autologin dev user

[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin dev --noreset --noclear --keep-baud 115200,57600,38400,9600 - tmux-256color
EOF

# disable sshd for root and enable a dedicated sshd for dev user like in the container
systemctl disable sshd.service

cat > /etc/systemd/system/update-hostname.service << 'EOF'
[Unit]
Description=Change host name based on QEMU fw_cfg value
After=network.target
ConditionPathExists=/sys/firmware/qemu_fw_cfg/by_name/opt/com.sandbox/hostname/raw

[Service]
Type=oneshot
ExecStart=/bin/bash -c '/usr/bin/hostnamectl set-hostname "$(cat /sys/firmware/qemu_fw_cfg/by_name/opt/com.sandbox/hostname/raw)"'
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

cat > /usr/local/bin/setup-proxy-from-fwcfg.sh << 'SH'
#!/usr/bin/env sh
set -euo pipefail

FWCFG=/sys/firmware/qemu_fw_cfg/by_name/opt/com.sandbox/proxy/raw

if [ -r "$FWCFG" ]; then
    proxy="$(cat "$FWCFG")"
    cat >> /etc/environment << EOF
HTTP_PROXY=$proxy
HTTPS_PROXY=$proxy
http_proxy=$proxy
https_proxy=$proxy
no_proxy="localhost,127.0.0.1"
EOF

    cat > /etc/apt/apt.conf.d/02proxy << PROXY_EOF
Acquire::http::Proxy "$proxy";
PROXY_EOF
fi
SH
chmod 755 /usr/local/bin/setup-proxy-from-fwcfg.sh

cat > /etc/systemd/system/setup-proxy.service << 'EOF'
[Unit]
Description=Setup env vars for proxy usage if QEMU fw_cfg value is present
After=network.target
ConditionPathExists=/sys/firmware/qemu_fw_cfg/by_name/opt/com.sandbox/proxy/raw

[Service]
Type=oneshot
ExecStart=/usr/local/bin/setup-proxy-from-fwcfg.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/dev-ssh-keys.service << 'EOF'
[Unit]
Description=Set up SSH authorized_keys from QEMU fw_cfg
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'cat /sys/firmware/qemu_fw_cfg/by_name/opt/com.sandbox/ssh_keys/raw | base64 -d > /home/dev/.ssh/authorized_keys && chmod 600 /home/dev/.ssh/authorized_keys && chown dev:dev /home/dev/.ssh/authorized_keys'
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/home-dev-workspace.mount << 'EOF'
[Unit]
Description=Dev workspace mount
After=network.target

[Mount]
What=workspace
Where=/home/dev/workspace
Type=9p
Options=trans=virtio
TimeoutSec=10

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/dev-sshd.service << 'EOF'
[Unit]
Description=OpenSSH server for dev user
After=network.target
Wants=network.target

[Service]
Type=notify
User=dev
Group=dev
ExecStart=/usr/sbin/sshd -D -e -f /home/dev/.ssh/sshd_config
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable update-hostname.service
systemctl enable setup-proxy.service
systemctl enable dev-sshd.service
systemctl enable home-dev-workspace.mount
systemctl enable dev-ssh-keys.service
