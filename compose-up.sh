#!/bin/sh

cd $(dirname $0)
set -e

# create docker network "hobbyfarm-dev"
if ! docker network inspect hobbyfarm-dev >/dev/null 2>&1; then
    docker network create hobbyfarm-dev
fi

# start docker-compose
docker-compose up -d "$@"

# save first run status
first_run="0"
if ! docker exec hf-kind [ -f /var/kubeadm-init-ran ]; then
    first_run="1"
fi

# wait for containerd to start
containerd_started="0"
for i in $(seq 1 30); do
    if docker exec hf-kind systemctl status containerd >/dev/null 2>&1; then
        containerd_started="1"
        break
    fi
    echo "waiting for containerd to start: ${i}s"
    sleep 1
done
if [ "$containerd_started" = "0" ]; then
    echo "containerd did not start after 30" >&2
    exit 1
fi

# initialize kind
docker exec -i hf-kind /kind/init.sh

# copy kube config to kubectl
docker exec hf-kind cat /etc/kubernetes/admin.conf \
    | docker exec -i hf-kubectl sh -c 'cat > /home/alpine/.kube/config' \

# seed if this is the first run
if [ "$first_run" = "1" ]; then
    ./compose-seed.sh
fi
