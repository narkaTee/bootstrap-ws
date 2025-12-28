#!/usr/bin/env bash
set -euo pipefail

echo "kvm-sandbox" > /etc/hostname
hostname kvm-sandbox

ip a
cat /etc/resolv.conf

host heise.de

#ping -c 3 1.1.1.1
#echo "nameserver 1.1.1.1" > /etc/resolv.conf
#cat /etc/resolv.conf

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
ansible-playbook sandbox.yaml
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
systemctl enable dev-sshd.service
