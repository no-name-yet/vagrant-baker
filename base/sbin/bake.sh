#!/bin/bash -ex
# bake.sh - Helper script from creating container images with pre-baked Vagrant
#           environment
#
# The way to use this script is to run this image while mounting a volume that
# contains a Vagrantfile, letting it run and then committing the results. For
# example:
#
# podman run -it --name=my-cont \
#   --privileged \
#   -v /path_to/dir_with/vagrant/file:/tmp/vagrant-app:Z \
#   quay.io/pod_utils/systemd-vagrant \
#   bake.sh /tmp/vagrant-app
# podman commit \
#   --change 'CMD []' \
#   my-cont my-img
#
# Note: the `--change` options on the `commit` command, those are essential for
# the resulting image to function properly
#
# Note: Since the 80_vagrant_sh.sh entry point runs its arguments as the vagrant
#       user, this script expects to be running as that user
#
# In addition to a path to a Vagrantfile, to following options can be passed to
# this script:
# --box-only - Don't leave configured VMs in the image, only downloaded boxes
#              This is useful for making containers with pre-cached images for
#              further customization
#
# All other arguments to this script are passed directly to `vagrant up`
#
main() {
    local -a options other_args
    local vagrant_app_dir='' box_only=''
    parse_args "$@"

    vagrant_app_dir="${vagrant_app_dir:?Path to Vagrant App missing}"
    if [[ "$vagrant_app_dir" != "$VAGRANT_CWD" ]]; then
        shopt -s nullglob failglob dotglob
        cp -vRL -t "$VAGRANT_CWD" "$vagrant_app_dir"/*
        chown -vR "$VAGRANT_USER:$VAGRANT_USER" "$VAGRANT_CWD"
    fi
    vagrant_up_down "$box_only" "${options[@]}" "${other_args[@]}"
    hardlink_boxes
    if [[ $box_only ]] && [[ "$vagrant_app_dir" != "$VAGRANT_CWD" ]]; then
        rm -rf "${VAGRANT_CWD:?}"/*
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --box-only)
            box_only=true;;
        --)
            shift; break;;
        -.*)
            options+="$1";;
        *)
            vagrant_app_dir="$1"; shift; break;;
        esac
        shift
    done
    other_args=("$@")
}

vagrant_up_down() {
    local box_only="${1?:}"
    shift

    # we don't want to quote here on purpose so we don't pass an empty string
    # when 'box_only' is blank (false)
    # shellcheck disable=2086
    vagrant up ${box_only:+--no-provision} "$@"
    vagrant halt
    if [[ $box_only ]]; then
        vagrant destroy -f
    fi
}

hardlink_boxes() {
    # Ensure all boxes can be read by the qemu user
    # Note: we must not run chown or chmod on any files that do not need it
    # because if causes overlayfs2 to copy the file even is the mode/owner is
    # not actually changed
    find "$VAGRANT_HOME/boxes" -type f -name \*.img \! -perm 444 -print0 \
        | xargs -0 -r sudo -n chmod -v 444
    find "$VAGRANT_HOME/boxes" -type f -name \*.img \
        \! \( -user qemu -group qemu \) -print0 \
        | xargs -0 -r sudo -n chown -v qemu:qemu
    # Hardlink boxes to the copies in the libvirt pool
    sudo -n hardlink -c -vv /var/lib/libvirt/images "$VAGRANT_HOME/boxes"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
