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
main() {
    local vagrant_app_dir="${1:?Path to Vagrant App missing}"
    if [[ "$vagrant_app_dir" != "$VAGRANT_CWD" ]]; then
        shopt -s nullglob failglob dotglob
        cp -RL -t "$VAGRANT_CWD" "$vagrant_app_dir"/*
        chown -R "$VAGRANT_USER:$VAGRANT_USER" "$VAGRANT_CWD"
    fi
    vagrant_up_down
    clean_boxes
}

vagrant_up_down() {
    vagrant up
    vagrant halt
}

clean_boxes() {
    vagrant box list --machine-readable \
        | sed -nre 's/^[0-9]+,,box-name,(.*)$/\1/p' \
        | xargs -rn 1 vagrant box remove -f --all
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
