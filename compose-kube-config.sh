#!/bin/sh

cd $(dirname $0)
set -e

docker exec -it hf-kind /kind/kube-config-local.sh
