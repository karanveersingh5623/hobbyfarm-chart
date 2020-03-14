#!/bin/sh

cd $(dirname $0)
set -e

docker exec -it hf-k3d sh -c '
    kubectl config view --raw \
        | sed "s/127\.0\.0\.1:6443/localhost:${K3D_PORT}/g"
'
