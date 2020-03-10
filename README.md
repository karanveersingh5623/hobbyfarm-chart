# HobbyFarm

This repo contains a Helm chart for deploying hobbyfarm as well as [documentation](https://hobbyfarm.github.io/hobbyfarm) on using the platform.

There is a GitHub Actions [Workflow](https://github.com/hobbyfarm/hobbyfarm/actions?query=workflow%3A%22publish+chart%22) that will publish a new version of the chart (to GitHub [Releases](https://github.com/hobbyfarm/hobbyfarm/releases)) if the `version` in `charts/hobbyfarm/Chart.yaml` is bumped.

## Releases & Versioning

HobbyFarm is released monthly, on or around the 1st of the month. 

Releases may be major, minor, or patch. Release types are determined at time of release depending on the content of the release. 

## Local Development

Hobbyfarm stores it's application data in CRDs, and a Kubernetes cluster is needed for local development

## via k3d

To install the chart locally on k3d, run:

```
./dev.sh
```

### via docker-compose

To run [kind](https://github.com/kubernetes-sigs/kind) locally and install all of the CRDs required for hobbyfarm, run:

```
# start kind
./compose-up.sh

# start kind, rebuilding the kind container
./compose-up.sh --build

# re-seed kind with CRDs and RBAC
./compose-seed.sh
```

`./compose-up.sh` does the following:
- create an external docker network called `hobbyfarm-dev`
- calls `docker-compose up`
    - creates or starts the `hf-kind` container
    - creates or starts the `hf-kubectl` containers
- set the kube config in `hf-kubectl`
- install CRDs and RBAC on first run

The `hf-kind` cluster listens on port 16220.  To run kubectl against the cluster, there are 2 options:

```
# use the kubectl container that docker-compose started
docker exec -it hf-kubectl sh
kubectl <options>

# dump a kubernetes config that can be used with kubectl
./compose-kube-config.sh
```

To modify `docker-compose` variables for your local environment, copy `.env.example` to `.env` and update variables as needed.
