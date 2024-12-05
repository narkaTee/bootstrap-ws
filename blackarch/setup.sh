#!/usr/bin/env bash
set -e
ansible-galaxy install -r requirements.yml
ansible-playbook -e @settings.yml blackarch.yml
