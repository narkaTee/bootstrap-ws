#!/usr/bin/env sh
set -x
find . -iname '*.sh' -exec shellcheck {} \;
shellcheck roles/dev_sandbox/scripts/*
ansible-lint
