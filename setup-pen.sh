#!/usr/bin/env bash
set -e
playbook="$1"
shift 1
ansible-playbook -e @inventory/role_vars/pen-test.yml "$playbook" "$@"
