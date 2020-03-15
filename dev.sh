#!/bin/sh

cd $(dirname $0)
set -e

usage() {
    [ -z "$1" ] || echo "$0: $1" >&2
    cat <<-EOF >&2
	manage local HobbyFarm development environment
	
	     usage: $0 <command>
	   	 
	where <command> is one of:
	
	    up          - start k3d
	    clear       - clear all CRD instances
	    seed        - reseed k3d with CRD instances
	    kubeconfig  - print kubeconfig
	    exec        - connect to a container with kubectl
	
	EOF
    exit 1
}

data_clear() {
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
}

data_seed() {
    # apply local seed data
    docker exec hf-k3d \
        kubectl apply -f /app/cicd/seed-data/
}

get_kubeconfig() {
    docker exec -it hf-k3d sh -c '
        kubectl config view --raw \
            | sed "s/127\.0\.0\.1:6443/localhost:${K3D_PORT}/g"
    '
}


case "$1" in
  clear)
    data_clear
    exit 0
  ;;
  seed)
    data_seed
    exit 0
  ;;
  kubeconfig)
    get_kubeconfig
    exit 0
  ;;
  exec)
    docker exec -it hf-k3d sh
    exit 0
  ;;
  up)
    continue
  ;;
  *)
    usage
  ;;
esac


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
        if [ ! $ready ]; then
            break
        fi
        echo "waiting for ns:${2} deployment:${3} to be ready: ${i}s"
        sleep 1
    done
    if [ $ready ]; then
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
    cat <<-EOF >@2
        starting existing docker-compose stack
        to recreate with updated containers, run:

            ./compose-up.sh --build

	EOF
    docker-compose start
else
    rebuild="1"
    echo "rebuilding docker-compose stack\n" >&2
    docker-compose up -d -V "$@"
fi

# wait for default namespace to be ready
echo "\nwaiting for default namespace to be ready" >&2
wait_secret "120" "default" "default-token"

if [ "$IMPORT_IMAGES" = "true" ]; then
    # pause kube-system deployments
    echo "\npausing kube-system deployments" >&2
    docker exec hf-k3d sh -c '
        kubectl -n kube-system get deploy -o name \
            | xargs kubectl -n kube-system scale --replicas=0
    '
fi

# apply CRDs
echo "\napplying CRDs" >&2
docker exec hf-k3d \
    kubectl apply -f /app/charts/hobbyfarm/crds/

# actions on first-run
if [ "$rebuild" = "1" ]; then
    echo "\nperforming first-run actions" >&2

    # copy service account token on first-run
    if [ "$rebuild" = "1" ]; then
        echo "\ncopying service account token" >&2
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

    echo "\nbuilding development images" >&2
    docker-compose -f cicd/docker-compose-local.yaml build

    # import sshd
    echo "\nimporting sshd" >&2
    docker image save hobbyfarm/local-sshd:latest \
        | docker exec -i hf-k3d ctr image import -

    # import tf-git
    echo "\nimporting tf-git" >&2
    docker image save hobbyfarm/local-tf-git:latest \
        | docker exec -i hf-k3d ctr image import -

    if [ "$IMPORT_IMAGES" = "true" ]; then
        # import kube-system images
        for image in $hf_images $k3d_images; do
            echo "\nimporting $image" >&2
            if ! docker image inspect "$image" >/dev/null 2>&1; then
                docker pull "$image"
            fi
            docker image save "$image" \
                | docker exec -i hf-k3d ctr image import -
        done

        # resume kube-system deployments
        echo "\nresuming kube-system deployments" >&2
        docker exec hf-k3d sh -c '
            kubectl -n kube-system get deploy -o name \
                | xargs kubectl -n kube-system scale --replicas=1
        '
    fi

    # wait for coredns to be ready
    echo "\nwaiting for coredns to be ready" >&2
    wait_deployment "300" "kube-system" "coredns"

    # apply infrastructure-related resources
    echo "\napplying infrastructure-related resources" >&2
    docker exec hf-k3d \
        kubectl apply -f /app/cicd/seed-infra/

    # wait for dev services to be ready
    echo "\nwaiting dev services to be ready" >&2
    wait_deployment "60" "default" "sshd"
    wait_deployment "60" "default" "tf-git"
    wait_deployment "300" "default" "terraform-controller"

    # seed data
    echo "\napplying seed data" >&2
        ./compose-data-seed.sh

    echo "\nfirst-run actions complete" >&2
fi

echo "\ndocker-compose stack has started\n" >&2

if [ "$rebuild" = "1" ]; then
    cat <<-EOF >&2
          hf-k3d was rebuilt
          to clean up previous volumes from the old hf-k3d container, run:

             docker volume prune

	EOF
fi
