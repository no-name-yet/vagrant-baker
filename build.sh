#!/bin/bash -e
# build.sh - Build all container images in this repo
#
# All parameters passed to this script are passed as options to `publish.sh` so
# care must be taken to not pass weird stuff
#

readonly BUILDER_IMAGE='quay.io/pod_utils/vagrant-baker-builder'
readonly IMAGE_TAG_PREFIX='quay.io/pod_utils/vagrant-baker-'

main() {
    local -a publish_args
    filter_publish_options "$@"

    if ! running_in_builder_container; then
        echo "It seems this script is not running inside the builder" >&2
        echo "container. Going to try to launch it" >&2
        launch_builder_container "${publish_args[@]}"
        return 0
    fi
    live_patch_builder
    build_all_images "$IMAGE_TAG_PREFIX" "${publish_args[@]}"
}

filter_publish_options() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --push)   publish_args+=("$1");;
            --skopeo) publish_args+=("$1" "$2"); shift;;
            --) break;;
        esac
        shift
    done
}

# shellcheck disable=SC2016
running_in_builder_container() {
    # Going to assume that if we're running as the `vagrant` user, have
    # `vagrant` and `buildah` in $PATH and NOPASSWD `sudo` access to the latter
    # then we're on the builder container
    if [[ $(id -un) != vagrant ]]; then
        echo "Not running as the 'vagrant' user" >&2
        return 1
    fi
    if ! type -p vagrant > /dev/null; then
        echo '`vagrant` not found in $PATH' >&2
        return 2
    fi
    if ! type -p buildah > /dev/null; then
        echo '`buildah` not found in $PATH' >&2
        return 3
    fi
    if ! can_sudo buildah; then
        echo 'We do not seen to have `sudo` access to `buildah`' >&2
        return 4
    fi
}

launch_builder_container() {
    # Try to launch the builder container using podman or docker.
    local src_dir script_name run_params

    src_dir="$(dirname "$(readlink -f "$0")")"
    script_name="$(basename "$(readlink -f "$0")")"
    run_params=(
        -it --rm --privileged -v "$src_dir:/workspace:Z"
        -e REGISTRY_AUTH_FILE=/workspace/.registry-auth.json
        "$BUILDER_IMAGE"
        "/workspace/$script_name"
        "$@"
    )

    if can_use_podman; then
        echo "Running builder container with podman" >&2
        (set -x; podman run "${run_params[@]}"; )
        return "$?"
    elif can_sudo podman; then
        echo "Running builder container with podman and sudo" >&2
        (set -x; sudo -n podman run "${run_params[@]}"; )
        return "$?"
    elif can_use_docker; then
        echo "Running builder container with docker" >&2
        (set -x; docker run "${run_params[@]}"; )
        return "$?"
    elif can_sudo docker; then
        echo "Running builder container with docker and sudo" >&2
        (set -x; sudo -n docker run "${run_params[@]}"; )
        return "$?"
    else
        echo "could not find a way to launch builer container!"
        return 1
    fi
}

can_use_podman() {
    type -p podman > /dev/null && (( UID == 0 ))
}

can_use_docker() {
    type -p docker > /dev/null \
        && [[ -S /var/run/docker.sock ]] \
        && [[ -r /var/run/docker.sock ]] \
        && [[ -w /var/run/docker.sock ]]
}

can_sudo() {
    local cmd

    for cmd in "$@"; do
        sudo -nl "$cmd" >& /dev/null || return 1
    done
}

live_patch_builder() {
    echo "Updating build script in container" >&2
    sudo -n cp -vfa -t /sbin /workspace/builder/sbin/*
}

build_all_images() {
    local tag_prefix image
    tag_prefix="${1:?}"
    shift

    echo "Going to build all images" >&2
    build_base_image "$tag_prefix" base "$@"
    build_base_image "$tag_prefix" builder "$@"
    build_box_image "$tag_prefix" centos8-single base "$@"
}

build_base_image() {
    local image tag_prefix
    tag_prefix="${1:?}"
    image="${2:?}"
    shift 2

    (
        set -x
        sudo buildah bud \
            --cache-from="${tag_prefix}$image" \
            --layers=true \
            -t "${tag_prefix}$image" \
            "/workspace/$image"
        publish.sh "${tag_prefix}$image" "$@"
    )
}

build_box_image() {
    local image base_image tag_prefix
    tag_prefix="${1:?}"
    image="${2:?}"
    base_image="${3:?}"
    shift 3

    (
        set -x
        derive.sh \
            --box-only \
            "${tag_prefix}$base_image" \
            "${tag_prefix}$image" \
            "/workspace/$image" \
            "$@"
    )
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
