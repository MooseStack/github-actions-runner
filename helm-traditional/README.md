# Helm Chart — GitHub Self-Hosted Runner

This chart deploys a traditional (non-ARC) GitHub Actions self-hosted runner as a Deployment on OpenShift/Kubernetes.

## What it creates

1. **Deployment** — pods containing the GitHub Runner on a UBI9 image
2. **Secret** — runner configurations used as environment variables in the Deployment pods
3. **ServiceAccount + Role/RoleBinding** — scoped to the release namespace, granting access to Tekton resources (pipelineruns, taskruns, pipelines, tasks) and core resources (pods, serviceaccounts)

## Build the runner image

### Option 1 — Manually build image using Podman

The image uses a two-stage build: a shared base image (`Containerfile`) plus the traditional runner layer (`Containerfile.traditional`).

```bash
# Build base image
podman build -t runner-base -f container_image/Containerfile container_image/

# Build traditional runner image from base
podman build -t runner --build-arg BASE_IMAGE=localhost/runner-base:latest \
  -f container_image/Containerfile.traditional container_image/

podman tag runner:latest your-registry.example.com/your-org/github-self-hosted-runner:latest
podman push your-registry.example.com/your-org/github-self-hosted-runner:latest
```

### Option 2 — Pipeline build using GitHub Actions

- [.github/workflows/traditional-image.yaml](../.github/workflows/traditional-image.yaml)
  - This uses the self-hosted runner deployed to OpenShift.

## Deploy with Helm CLI

1. Edit [values.yaml](values.yaml) with your requirements

2. Install the chart:

```bash
helm install gh-runner ./helm-traditional -n gh-runner \
  --create-namespace \
  --values ./helm-traditional/values.yaml \
  --set secrets.GITHUB_PAT='YOUR_GH_PAT'
```

### Available `--set` options

```bash
# If using a PAT
    --set secrets.GITHUB_PAT=""

# If using GitHub App
    --set secrets.GITHUB_APP_ID=""
    --set secrets.GITHUB_APP_INSTALL_ID=""
    --set secrets.GITHUB_APP_PEM=""

# GitHub Actions Runner token (not required if using PAT or GitHub App)
    --set secrets.GITHUB_RUNNER_TOKEN=""

# GITHUB_DOMAIN - leave blank if "github.com"
    --set secrets.GITHUB_DOMAIN=""
    --set secrets.GITHUB_OWNER="username"
    --set secrets.GITHUB_REPOSITORY="reponame"

# Runner workload directory
    --set secrets.GITHUB_RUNNER_WORKDIR="/home/runner/_work"
    --set secrets.GITHUB_RUNNER_LABEL="ubi9-gh-runner,openshift"
    --set secrets.GITHUB_RUNNER_EPHEMERAL="" # options are "true" or empty ""

# Organization level runner group name. Must already exist. GITHUB_REPOSITORY should not be filled out if using this.
    --set secrets.GITHUB_ORG_RUNNER_GROUP=""
```

## Deploy with ArgoCD

1. Reference and deploy: [argocd-app-reference.yaml](argocd-app-reference.yaml)
   - Update the project and namespace names.
2. Manually modify the values of Secret `github-actions-runner-secret` in OpenShift/Kubernetes
   - Use one of: PAT, Runner Token, or GH App.
   - Update `GITHUB_DOMAIN`, `GITHUB_OWNER`, `GITHUB_REPOSITORY` with your repo info.
3. Restart the deployment / delete old pods to reflect Secret value changes.
