#!/bin/bash -e
# 50_libvirt.sh - Startup libvirt services and launch next entrypoint
#
cleanup() {
    # shellcheck disable=SC2046
    kill \
        $(cat /var/run/libvirtd.pid) \
        $(cat /var/run/virtlockd.pid) \
        $(cat /var/run/virtlogd.pid)
}

/usr/sbin/virtlogd -d
/usr/sbin/virtlockd -d
/usr/sbin/libvirtd -d

"$@"
