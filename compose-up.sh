#!/bin/sh

cd $(dirname $0)
set -e

# when IMPORT_IMAGES=true
# load hobbyfarm and kube-system images from docker
# this is useful on slow networks
hf_images='
    hobbyfarm/terraform-controller:12032019
    oats87/terraform-controller-executor:hfv1
'
k3d_images='
    coredns/coredns:1.6.3
    rancher/klipper-helm:v0.2.3
    rancher/klipper-lb:v0.1.2
    rancher/metrics-server:v0.3.6
    rancher/local-path-provisioner:v0.0.11
    traefik:1.7.19
'

wait_secret() {
    ready="0"
    for i in $(seq 1 $1); do
        ready=$(docker exec hf-k3d \
            kubectl -n "$2" get secret -o name | grep "$3" | wc -l)
        
        if [ "$ready" != "0" ]; then
            break
        fi
        echo "waiting for ns:${2} secret:${3} to be ready: ${i}s"
        sleep 1
    done
    if [ "$ready" = "0" ]; then
        echo "ns:${2} secret:${3} not ready after ${1} seconds" >&2
        exit 1
    fi
}

wait_deployment() {
    ready="0"
    for i in $(seq 1 $1); do
        ready=$(docker exec hf-k3d \
            kubectl -n "$2" get deployment "$3" -o 'jsonpath={.status.readyReplicas}')
        ready="${ready:-0}"
        if [ "$ready" != "0" ]; then
            break
        fi
        echo "waiting for ns:${2} deployment:${3} to be ready: ${i}s"
        sleep 1
    done
    if [ "$ready" = "0" ]; then
        echo "ns:${2} deployment:${3} not ready after ${1} seconds" >&2
        echo "consider setting 'export IMPORT_IMAGES=true' if you are on a slow network"
        exit 1
    fi
}

# create docker network "hobbyfarm-dev"
if ! docker network inspect hobbyfarm-dev >/dev/null 2>&1; then
    docker network create hobbyfarm-dev
fi

# create docker volume "hobbyfarm-kube-sa"
if ! docker volume inspect hobbyfarm-kube-sa >/dev/null 2>&1; then
    docker volume create hobbyfarm-kube-sa
fi

# start docker-compose
rebuild="0"
if [ "$#" = "0" ] && docker inspect hf-k3d >/dev/null 2>&1; then
    echo "starting existing docker-compose stack" >&2
    echo "to recreate with updated containers, run:" >&2
    echo "" >&2
    echo "   ./compose-up.sh --build" >&2
    echo "" >&2
    echo "" >&2
    docker-compose start
else
    rebuild="1"
    echo "rebuilding docker-compose stack" >&2
    echo "" >&2
    docker-compose up -d -V "$@"
fi

# wait for default namespace to be ready
echo "" >&2
echo "waiting for default namespace to be ready" >&2
wait_secret "120" "default" "default-token"

if [ "$IMPORT_IMAGES" = "true" ]; then
    # pause kube-system deployments
    echo "" >&2
    echo "pausing kube-system deployments" >&2
    docker exec hf-k3d sh -c '
        kubectl -n kube-system get deploy -o name \
            | xargs kubectl -n kube-system scale --replicas=0
    '
fi

# apply CRDs
echo "" >&2
echo "applying CRDs" >&2
docker exec hf-k3d \
    kubectl apply -f /app/charts/hobbyfarm/crds/

# actions on first-run
if [ "$rebuild" = "1" ]; then
    echo "" >&2
    echo "performing first-run actions" >&2

    # copy service account token on first-run
    if [ "$rebuild" = "1" ]; then
        echo "" >&2
        echo "copying service account token" >&2
        docker exec hf-k3d sh -c '
                cd /var/run/secrets/kubernetes.io/serviceaccount
                secret=$(kubectl get secret \
                     -o name  \
                    | grep "default-token")
                kubectl get "$secret" \
                    -o "jsonpath={.data.ca\.crt}" \
                    | base64 -d \
                    > ca.crt
                kubectl get "$secret" \
                    -o "jsonpath={.data.namespace}" \
                    | base64 -d \
                    > namespace
                kubectl get "$secret" \
                    -o "jsonpath={.data.token}" \
                    | base64 -d \
                    > token
            '
    fi

    echo "" >&2
    echo "building development images" >&2
    docker-compose -f cicd/docker-compose-local.yaml build

    # import sshd
    echo "" >&2
    echo "importing sshd" >&2
    docker image save hobbyfarm/local-sshd:latest \
        | docker exec -i hf-k3d ctr image import -

    # import tf-git
    echo "" >&2
    echo "importing tf-git" >&2
    docker image save hobbyfarm/local-tf-git:latest \
        | docker exec -i hf-k3d ctr image import -

    if [ "$IMPORT_IMAGES" = "true" ]; then
        # import kube-system images
        for image in $hf_images $k3d_images; do
            echo "" >&2
            echo "importing $image" >&2
            if ! docker image inspect "$image" >/dev/null 2>&1; then
                docker pull "$image"
            fi
            docker image save "$image" \
                | docker exec -i hf-k3d ctr image import -
        done

        # resume kube-system deployments
        echo "" >&2
        echo "resuming kube-system deployments" >&2
        docker exec hf-k3d sh -c '
            kubectl -n kube-system get deploy -o name \
                | xargs kubectl -n kube-system scale --replicas=1
        '
    fi

    # wait for coredns to be ready
    echo "" >&2
    echo "waiting for coredns to be ready" >&2
    wait_deployment "300" "kube-system" "coredns"

    # apply infrastructure-related resources
    echo "" >&2
    echo "applying infrastructure-related resources" >&2
    docker exec hf-k3d \
        kubectl apply -f /app/cicd/seed-infra/

    # wait for dev services to be ready
    echo "" >&2
    echo "waiting dev services to be ready" >&2
    wait_deployment "60" "default" "sshd"
    wait_deployment "60" "default" "tf-git"
    wait_deployment "300" "default" "terraform-controller"

    # seed data
    echo "" >&2
    echo "applying seed data" >&2
        ./compose-data-seed.sh

    echo "" >&2
    echo "first-run actions complete" >&2
fi

echo "" >&2
echo "docker-compose stack has started" >&2
echo "" >&2

if [ "$rebuild" = "1" ]; then
    echo "hf-k3d was rebuilt" >&2
    echo "to clean up previous volumes from the old hf-k3d container, run:" >&2
    echo "" >&2
    echo "   docker volume prune" >&2
    echo "" >&2
fi
