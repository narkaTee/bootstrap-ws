#!/bin/bash
set -e

# Inject SSH keys from environment variable if provided
if [ -n "$SANDBOX_SSH_KEYS" ]; then
    echo "$SANDBOX_SSH_KEYS" | base64 -d > /home/dev/.ssh/authorized_keys
    chmod 600 /home/dev/.ssh/authorized_keys
    chown -R dev:dev /home/dev/.ssh
fi

if [ $# -gt 0 ]; then
    exec "$@"
fi

exec /usr/sbin/sshd -D -e -f /home/dev/.ssh/sshd_config
