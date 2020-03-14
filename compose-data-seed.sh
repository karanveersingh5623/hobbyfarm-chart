#!/bin/sh

cd $(dirname $0)
set -e

# apply local seed data
docker exec hf-k3d \
    kubectl apply -f /app/cicd/seed-data/
