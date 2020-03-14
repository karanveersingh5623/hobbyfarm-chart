#!/bin/sh

cd $(dirname $0)
set -e

# clear all hobbyfarm crd instances
docker exec hf-k3d sh -c '
        set -e pipefail
        kubectl get crd \
            | grep -F hobbyfarm.io \
            | cut -d" " -f1 \
            | xargs \
            | tr " " "," \
            | xargs kubectl get --all-namespaces -o name \
            | xargs -r kubectl delete
    '
