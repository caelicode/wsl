#!/usr/bin/env bash
# CaeliCode WSL — User creation tests
# Tests that the pre-created default user is correctly configured.
set -euo pipefail

# shellcheck source=test/common.sh
source "$(dirname "$0")/common.sh"

echo "── User Creation Tests ──"

# Default user exists and is configured correctly
check "caelicode user exists" getent passwd caelicode
# shellcheck disable=SC2016  # expansion must happen inside bash -c, not here
check "caelicode uid is 1000" bash -c '[ "$(id -u caelicode)" = "1000" ]'
check "stock ubuntu user removed" bash -c '! getent passwd ubuntu'
check "caelicode home dir" test -d /home/caelicode
check "caelicode shell is zsh" grep -q "caelicode.*/bin/zsh" /etc/passwd
check "caelicode in sudo group" bash -c 'id -nG caelicode | grep -qw sudo'
# sudo -n: /etc/sudoers.d is root-only and the suite runs as the image's
# non-root default user — these also prove NOPASSWD sudo actually works.
check "caelicode sudoers file" sudo -n test -f /etc/sudoers.d/caelicode
# shellcheck disable=SC2016  # expansion must happen inside bash -c, not here
check "sudoers file mode 0440" bash -c '[ "$(sudo -n stat -c %a /etc/sudoers.d/caelicode)" = "440" ]'

# Shell config is in place
check "caelicode has .zshrc" test -f /home/caelicode/.zshrc
check "caelicode has .bashrc" test -f /home/caelicode/.bashrc
check "caelicode has .bash_aliases" test -f /home/caelicode/.bash_aliases

# Skel files available for future users
check "Skel .bashrc available" test -f /etc/skel/.bashrc
check "Skel .bash_aliases available" test -f /etc/skel/.bash_aliases
check "Skel .zshrc available" test -f /etc/skel/.zshrc

# WSL default user is set
check "wsl.conf default user" grep -q "default = caelicode" /etc/wsl.conf

summarize "User Creation Results"
