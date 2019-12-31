#!/bin/bash -e
# derive.sh - A script for deriving a Vagrant-based image from another using
#             buildah
#
# This script accepts 3 positional arguments:
# 1. `from`    - the base image to build from
# 2. `to`      - the name of the image being built
# 3. `app_dir` - the directory where Vagrant files for setting up VM and making
#                changes are found. It is passed to `bake.sh`.
# This script also accepts 3 optional arguments:
# --push       - If given the built image is pushed to the registry specified
#                in its name
# --skopeo DST - If given, skopeo is used to copy the built image to the
#                specified destination. This is useful for e.g. to store the
#                image in a local mounted directory
# All other arguments and options given to this script are passed to `bake.sh`
#
# On order to provide credentials for pushing images one should mount an
# authentication JSON file to the container and set REGISTRY_AUTH_FILE to point
# to it, The JSON file can be generated with:
#
#     buildah login --authfile /path/to/auth.json
#
# Intermediate container images are stores in a container storage that is
# created at the location pointed by CONTAINER_GRAPH_ROOT, see the Dockerfile
# for the default value of that variable.
#
main() {
    local from='' to='' app_dir='' container
    local -a publish_args other_args

    parse_args "$@"

    set -x
    container="$(sudo buildah from "$from")"
    setup_mounts "$container"
    bake.sh "$app_dir" "${other_args[@]}"
    hardlink_boxes "$container"
    teardown_mounts "$container"
    sudo buildah commit --rm "$container" "$to"
    publish.sh "${publish_args[@]}" "$to"
}

parse_args() {
    local -a positional

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --push)
            publish_args+=("$1");;
        --skopeo)
            publish_args+=("$1" "$2"); shift;;
        --)
            other_args+=("$1"); shift; break;;
        -?*)
            other_args+=("$1");;
        *)
            if [[ ${#positional[@]} -lt 3 ]]; then
                positional+=("$1")
            else
                other_args+=("$1")
            fi;;
        esac
        shift
    done
    from="${positional[0]:?Base image to build from not specified}"
    to="${positional[1]:?Destination image name not specified}"
    app_dir="${positional[2]:?Vagrant application directory no specified}"
    other_args+=("$@")
}

readonly MOUNT_POINTS=(
    "$VAGRANT_CWD"
    "$VAGRANT_HOME"
    /etc/libvirt/qemu
    /var/lib/libvirt
)

setup_mounts() {
    local container container_mp mp

    container="${1:?}"

    sudo kill "$(< /var/run/libvirtd.pid)"
    container_mp="$(sudo buildah mount "$container")"
    for mp in "${MOUNT_POINTS[@]}"; do
        sudo mount --bind "${container_mp}${mp}" "$mp"
    done
    sudo libvirtd -d
}

teardown_mounts() {
    local container mp

    container="${1:?}"

    sudo kill "$(< /var/run/libvirtd.pid)"
    for mp in "${MOUNT_POINTS[@]}"; do
        sudo umount "$mp"
    done
    sudo buildah umount "$container"
    sudo libvirtd -d
}

hardlink_boxes() {
    # While this is also done in bake.sh, we need to redo it here, because it
    # sometimes fails to work across different mount points
    local container container_mp
    container="${1:?}"

    container_mp="$(sudo buildah mount "$container")"

    sudo -n hardlink -c -f -vv \
        "$container_mp/var/lib/libvirt/images" \
        "${container_mp}$VAGRANT_HOME/boxes"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
