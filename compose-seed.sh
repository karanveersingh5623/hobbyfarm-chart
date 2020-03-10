#!/bin/sh

cd $(dirname $0)
set -e

# wait for default namespace to be ready
token_count="0"
for i in $(seq 1 120); do
    token_count=$(docker exec hf-kubectl kubectl get secret -o name | grep "default-token" | wc -l)
    if [ "$token_count" != "0" ]; then
        break
    fi
    echo "waiting for default namespace to be ready: ${i}s"
    sleep 1
done
if [ "$token_count" = "0" ]; then
    echo "default namespace not ready after 120 seconds" >&2
    exit 1
fi

# apply CRDs
docker exec hf-kubectl \
    kubectl apply -f /app/charts/hobbyfarm/crds/

# apply rbac
docker exec hf-kubectl sh -c '
    sed -r "s/\{\{ \.Release\.Namespace \}\}/default/g" \
        /app/charts/hobbyfarm/templates/gargantua/rbac.yaml \
        | kubectl apply -f -
    '
