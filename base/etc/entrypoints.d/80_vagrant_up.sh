#!/bin/bash -e
# 80_vagrant_up.sh - Starup prebaked Vagrant VMs
#
vag_user() {
    runuser -u "$VAGRANT_USER" -p -- "$@"
}

if [[ -e $VAGRANT_CWD/Vagrantfile ]]; then
    trap 'vag_user vagrant halt' EXIT
    vag_user vagrant up
fi

vag_user "$@"
