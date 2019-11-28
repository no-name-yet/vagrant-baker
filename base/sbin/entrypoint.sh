#!/bin/bash -e
# entrypoint.sh - nested container entry points framework
#
# This script tries to run the 1st script found in /etc/entrypoints.d while
# passing all other scripts found there to it as command-line arguments followed
# by all the command-line arguments given to the container
#
# The idea is that each script in `/etc/entrypoints.d/*.sh` will do some
# initialization, setup cleanup functions as needed and then invoke its $1
# argument as a script. That way we get a chain of scripts nested within one
# another where the final script can even come from end-user input
#
shopt -s nullglob

if [[ $# -gt 0 ]] && [[ -z $1 ]]; then
    # Podman seems to have an issue where `podman commit` cannot create images
    # without a CMD setting, and adding `--change='CMD []'` results in the
    # command being an array with a single string in it. Therefor we detect that
    # particular case above and treat it as if a command was not given
    set --
fi


ENTRY_POINTS=(/etc/entrypoints.d/*.sh)

if [[ ${#ENTRY_POINTS[@]} -le 0 ]] && [[ $# -le 0 ]]; then
    echo "$0: No entry points configured in the container" >&2
    echo "$0: and none given on the command-line. Exiting." >&2
    exit 1
elif [[ ${#ENTRY_POINTS[@]} -gt 0 ]] && [[ $# -le 0 ]]; then
    echo "$0: No command-line arguments given to container," >&2
    echo "$0: will run entry points and then sleep indefinitely" >&2
    set -- sleep inf
fi

"${ENTRY_POINTS[@]}" "$@"
