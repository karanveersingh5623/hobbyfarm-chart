# HobbyFarm

This repo contains a Helm chart for deploying hobbyfarm as well as [documentation](https://hobbyfarm.github.io/hobbyfarm) on using the platform.

There is a GitHub Actions [Workflow](https://github.com/hobbyfarm/hobbyfarm/actions?query=workflow%3A%22publish+chart%22) that will publish a new version of the chart (to GitHub [Releases](https://github.com/hobbyfarm/hobbyfarm/releases)) if the `version` in `charts/hobbyfarm/Chart.yaml` is bumped.

## Releases & Versioning

HobbyFarm is released monthly, on or around the 1st of the month. 

Releases may be major, minor, or patch. Release types are determined at time of release depending on the content of the release. 

## Local Development via docker-compose

Hobbyfarm stores it's application data in CRDs, and a Kubernetes cluster is needed for local development

To run `k3d` locally in `docker-compose` and install all of the CRDs required for hobbyfarm, run:

```
# start k3d
./compose-up.sh

# -- or --
# start the stack, building changes to local dev container
# only needed if a file in ./cicd/docker-local has changed
./compose-up.sh --build
```

`./compose-up.sh` does the following:
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
docker exec -it hf-k3d sh
kubectl <options>

# dump a kubernetes config that can be used with kubectl
./compose-kube-config.sh
```

To re-apply or remove the CRD instances in `./cicd/seed-data`, run:

```
# re-seed k3d with hobbyfarm CRD instances
./compose-data-seed.sh

# clear all hobbyfarm CRD instances
./compose-data-clear.sh
```

To modify `docker-compose` variables for your local environment, copy `.env.example` to `.env` and update variables as needed.
