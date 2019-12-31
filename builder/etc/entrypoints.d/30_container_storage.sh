#!/bin/bash -e
# 30_container_storage.sh - Setup container storage configuration
#
mkdir -p "$CONTAINER_GRAPH_ROOT"
mkdir -p "$CONTAINER_RUN_ROOT"

cat > /etc/containers/storage.conf <<EOF
[storage]
driver = "overlay"
runroot = "$CONTAINER_RUN_ROOT"
graphroot = "$CONTAINER_GRAPH_ROOT"

[storage.options]
additionalimagestores = [
]
size = ""
override_kernel_check = "true"
EOF

"$@"
