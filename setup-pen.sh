#!/usr/bin/env bash
set -e
ansible-playbook -e @inventory/role_vars/pen-test.yml playbook-blackarch.yaml "$@"
