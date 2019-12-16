#!/bin/bash -e
# publish.sh - A script for pushing container images to remote locations
#
# The script's positional arguments are the names of the images to deal with.
# The script also accepts the following options:
# --push       - If given the image is pushed to the registry specified in its
#                name
# --skopeo DST - If given, skopeo is used to copy the image to the specified
#                destination. This is useful for e.g. to store the image in a
#                local mounted directory.
#                The skopeo destination can be partially given, in which case
#                the missing part will be completed from the image. For
#                example, for the image 'reg/ns/name:lbl', and a skopeo
#                destination of 'oci:/some/path' the image will be copied to
#                'oci:/some/path:reg/ns/name:lbl'.
# Both options may be given. If no options are given, this script does nothing.
#
main() {
    local to_skopeo='' to_push='' skopeo_name
    local -a images

    parse_args "$@"

    if [[ $to_push ]]; then
        for image in "${images[@]}"; do
            (set -x; sudo buildah push "$image")
        done
    fi
    if [[ $to_skopeo ]]; then
        for image in "${images[@]}"; do
            skopeo_name="$(get_full_skopeo_name "$to_skopeo" "$image")"
            (
                set -x
                sudo skopeo copy "containers-storage:$image" "$skopeo_name"
            )
        done
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --push)
            to_push=true;;
        --skopeo)
            to_skopeo="$2"; shift;;
        --)
            shift; break;;
        -?*) ;;
        *)
            images+=("$1")
        esac
        shift
    done
    images+=("$@")
}

get_full_skopeo_name() {
    local partial image
    partial="${1:?}"
    image="${2:?}"

    case "$partial" in
        container-storage:*|docker://*|docker-daemon:*)
            echo "${partial%%:*}:$(fill_docker_reference "${partial#*:}" "$image")";;
        dir:*)
            echo "$partial";;
        docker-archive:?*:?*|oci:?*:?*)
            local prefix path reference
            prefix="${partial%%:*}"
            path="${partial#*:}"
            path="${path%%:*}"
            reference="${partial#*:*:}"
            echo "$prefix:$path:$(fill_docker_reference "$reference" "$image")"
            ;;
        docker-archive:?*|oci:?*)
            echo "${partial%:}:$image";;
        ostree:?*@/*)
            local reference
            reference="${partial#*:}"
            path="${reference##*@/}"
            reference="${reference%@/*}"
            echo "ostree:$(fill_docker_reference "$reference" "$image")@/$path"
            ;;
        ostree:?*)
            local reference
            reference="${partial#*:}"
            echo "ostree:$(fill_docker_reference "$reference" "$image")"
            ;;
        *)
            echo "Invalid skopeo URL given" >&2
            return 1
            ;;
    esac
}

fill_docker_reference() {
    local reference image
    reference="${1:?}"
    image="${2:?}"

    local repo namespace name label
    parse_docker_image "$image"

    case "$reference" in
        ?*.?*/?*/?*:?*) echo "${reference}";;
        ?*.?*/?*/?*:)   echo "${reference}$label";;
        ?*.?*/?*/?*)    echo "${reference}";;
        ?*.?*/?*/)      echo "${reference}$name:$label";;
        ?*.?*/?*:)      echo "${reference}$label";;
        ?*.?*/?*)       echo "${reference}";;
        ?*.?*/)         echo "${reference}${namespace}$name:$label";;
        ?*.?*)          echo "${reference}/${namespace}$name:$label";;
        ?*/?*:?*)       echo "${repo}${reference}";;
        ?*/?*:)         echo "${repo}${reference}$label";;
        ?*/?*)          echo "${repo}${reference}";;
        ?*/)            echo "${repo}${reference}$name:$label";;
        */*)
            echo 'Invalid container reference given' >&2
            return 1
            ;;
        *:)             echo "${repo}${namespace}$reference:$label";;
        *)              echo "${repo}${namespace}$reference";;
    esac
}

parse_docker_image() {
    image="${1:?}"

    repo='docker.io/'
    namespace=''
    name=''
    label=latest
    case "$image" in
        ?*.?*/?*/?*:*)
            repo="${image%%/*}/"
            namespace="${image#*/}"
            namespace="${namespace%%/*}/"
            name="${image#*/*/}"
            label="${name#*:}"
            name="${name%%:*}"
            ;;
        ?*.?*/?*/?*)
            repo="${image%%/*}/"
            namespace="${image#*/}"
            namespace="${namespace%%/*}/"
            name="${image#*/*/}"
            ;;
        ?*.?*/?*:*)
            repo="${image%%/*}/"
            name="${image#*/}"
            label="${name#*:}"
            name="${name%%:*}"
            ;;
        ?*.?*/?*)
            repo="${image%%/*}/"
            name="${image#*/}"
            ;;
        ?*/?*:*)
            namespace="${image%%/*}/"
            name="${image#*/}"
            label="${name#*:}"
            name="${name%%:*}"
            ;;
        ?*/?*)
            namespace="${image%%/*}/"
            name="${image#*/}"
            ;;
        */*)
            echo 'Invalid docke image given' >&2
            return 1
            ;;
        *:*)
            label="${image#*:}"
            name="${image%%:*}"
            ;;
        *)
            name="$image"
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
