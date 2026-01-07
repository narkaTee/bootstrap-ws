#!/usr/bin/env bash
set -e

# The wonderful line makes sure p10k can initilize and download gitstatusd
echo exit | script -qec zsh /dev/null >/dev/null

. /home/dev/.config/setup/tools.sh
# install n
yes | n
# the path update and unset in the n bootstrap function does not work when running a script
# in an interactive shell it works flawless...
# For now this is good enough to source the tools setup again and unset the n function manually
. /home/dev/.config/setup/tools.sh
unset -f n
# pre install nodejs lts
n install lts

# pre install sdk man, yep that is quite sketchy but manually installing is complicated
curl -s "https://get.sdkman.io?ci=true&rcupdate=false" | bash

if sudo -n whoami &> /dev/null; then
    # pre install linux brew
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
