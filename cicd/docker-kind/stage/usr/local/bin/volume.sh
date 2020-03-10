#!/bin/sh

set -e

pwd=$(pwd)
cd /var

# backup on first run
if ! [ -f var.tar.gz ]; then
    mv lib/containerd/io.containerd.content.v1.content .

    find . -mindepth 1 -maxdepth 1 \
        -not -name "io.containerd.content.v1.content" \
        | xargs tar -czf var.tar.gz

    mv io.containerd.content.v1.content lib/containerd
fi

# restore if container has restarted
if ! [ -f /etc/kubeadm-init-ran ]; then
    mv lib/containerd/io.containerd.content.v1.content .

    find . -mindepth 1 -maxdepth 1 \
        -not -name "io.containerd.content.v1.content" \
        -a -not -name "var.tar.gz" \
        | xargs rm -rf

    tar -xzf var.tar.gz

    mv io.containerd.content.v1.content lib/containerd
fi

cd "$pwd"
exec "$@"
