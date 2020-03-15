# Contributing to HobbyFarm

Welcome to the Farm! We're excited that you're interested in contributing to HobbyFarm.

This project is currently in the very early stages but we encourage you to poke holes and then open issues/PRs to fix those holes!


## Local Development via docker-compose

Hobbyfarm stores it's application data in CRDs, and a Kubernetes cluster is needed for local development.

To run `k3d` locally in `docker-compose` and install all of the CRDs required for hobbyfarm, run:

```
# start k3d
./dev.sh up

# -- or --
# start the stack, building changes to local dev container
# only needed if a file in ./cicd/docker-local has changed
./dev.sh up --build
```

`./dev.sh up` does the following:
- creates an external docker network called `hobbyfarm-dev`
- creates an external docker volume for kube service account credentials called `hobbyfarm-kube-sa`
- calls `docker-compose up`
    - creates or starts the `hf-k3d` container
- actions on first-run:
    - installs terraform controller into `hf-k3d` on first-run
    - installs a local terraform git repository into `hf-k3d`
    - installs a local `sshd` "vm" into `hf-k3d`
    - installs CRDs and seed data on first run
    - creates an admin user with username `admin` and password `admin`

The `hf-k3d` cluster listens on port 16220.  To run kubectl against the cluster, there are 2 options:

```
# use the kubectl container that docker-compose started
./dev.sh exec
kubectl <options>

# dump a kubernetes config that can be used with kubectl
./dev.sh kubeconfig
```

To re-apply or remove the CRD instances in `./cicd/seed-data`, run:

```
# re-seed k3d with hobbyfarm CRD instances
./dev.sh seed

# clear all hobbyfarm CRD instances
./dev.sh clear
```

To modify `docker-compose` variables for your local environment, copy `.env.example` to `.env` and update variables as needed.
