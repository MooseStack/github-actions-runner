# Helm Chart — ARC (Actions Runner Controller) on OpenShift

This chart deploys [Actions Runner Controller (ARC)](https://github.com/actions/actions-runner-controller) on OpenShift with autoscaling ephemeral runner pods. It includes the upstream ARC Helm charts as sub-chart dependencies and adds the OpenShift-specific RBAC and prerequisites to make it work on OpenShift.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  OpenShift Cluster — single namespace (e.g. arc-systems)             │
│                                                                      │
│  ┌─ Parent Chart Resources ────────────────────────────────────┐     │
│  │  Secret (GitHub App or PAT credentials)                     │     │
│  │  ConfigMap (OpenShift-injected trusted CA bundle for GHES)  │     │
│  │  ServiceAccount (runner pods)                               │     │
│  │  RoleBinding      — runner SA → anyuid SCC                  │     │
│  │  Role/RoleBinding — controller SA → nonroot-v2 SCC          │     │
│  │  Role/RoleBinding — ArgoCD SA → ARC CRs (if argocd.enabled) │     │
│  └─────────────────────────────────────────────────────────────┘     │
│                                                                      │
│  ┌─ Sub-chart: gha-runner-scale-set-controller ───────────────┐      │
│  │  ARC Controller Manager (Deployment)                       │      │
│  │  └─ watches AutoScalingRunnerSet CRs                       │      │
│  │  └─ mounts trusted CA bundle for GHES TLS                  │      │
│  └────────────────────────────────────────────────────────────┘      │
│                                                                      │
│  ┌─ Sub-chart: gha-runner-scale-set ──────────────────────────┐      │
│  │  AutoScalingRunnerSet CR                                   │      │
│  │  Listener Pod ← long-poll to GitHub Actions API            │      │
│  │  EphemeralRunner pods (scale 0 → N on demand)              │      │
│  │  └─ UBI9-based runner image (anyuid SCC)                   │      │
│  └────────────────────────────────────────────────────────────┘      │
│                                                                      │
│  GitHub Enterprise Server  ←── TLS via CA bundle                     │
└──────────────────────────────────────────────────────────────────────┘
```

## What it creates

| # | Resource | Template | Purpose |
|---|----------|----------|---------|
| 1 | **Secret** | `secret.yaml` | GitHub App or PAT credentials referenced by the runner scale set |
| 2 | **ConfigMap** | `configmap-tls.yaml` | Annotated with `config.openshift.io/inject-trusted-cabundle` so OpenShift auto-injects the cluster CA bundle (needed for GHES TLS) |
| 3 | **ServiceAccount** | `rbac-runner.yaml` | Runner pod identity (`arc-runner-sa` by default) |
| 4 | **RoleBinding → ClusterRole** | `rbac-runner.yaml` | Grants the runner SA usage of the `anyuid` SCC (ClusterRole `system:openshift:scc:anyuid`) |
| 5 | **Role / RoleBinding** | `rbac-controller.yaml` | Grants the controller SA usage of the `nonroot-v2` SCC |
| 6 | **Role / RoleBinding** (optional) | `rbac-argocd.yaml` | Grants the ArgoCD application controller permission to manage `actions.github.com` CRs in this namespace (enabled when `argocd.enabled: true`) |
| 7 | **gha-runner-scale-set-controller** | sub-chart | ARC controller manager — watches CRs, mounts trusted CA bundle for GHES |
| 8 | **gha-runner-scale-set** | sub-chart | AutoScalingRunnerSet CR, listener pod, and ephemeral runner pods |

## Prerequisites

- OpenShift 4.12+
- Helm 3.x (Included with ArgoCD if using that)
- A GitHub PAT or GitHub App credentials
- Namespace must already exist

## Step 1 — Build the ARC-compatible runner image

The image uses a two-stage build: a shared base image (`Containerfile`) plus the ARC runner layer (`Containerfile.arc`).

```bash
# Build base image
podman build -t runner-base -f container_image/Containerfile container_image/

# Build ARC runner image from base
podman build -t arc-runner-ubi9:latest --build-arg BASE_IMAGE=localhost/runner-base:latest \
  -f container_image/Containerfile.arc container_image/

podman tag arc-runner-ubi9:latest your-registry.example.com/your-org/arc-runner-ubi9:latest
podman push your-registry.example.com/your-org/arc-runner-ubi9:latest
```

## Step 2 - Option A — Deploy with Helm CLI

1. Update [helm-arc-openshift/values.yaml](values.yaml) with your environment-specific settings.
   - **Tip:** Search for `#UPDATE THIS` in `values.yaml` to find all values that must be customized.

2. Deploy:

```bash
helm dependency build ./helm-arc-openshift
helm install arc-ocp ./helm-arc-openshift -n arc-systems -f values.yaml
```

### Key values to configure

| Value | Description |
|---|---|
| `runners.githubConfigUrl` | GitHub config URL (repository, org, or enterprise) — set on the runner sub-chart, NOT in secrets |
| `secrets.github_token` | If using a PAT |
| `secrets.github_app_id` | If using GitHub App |
| `secrets.github_app_installation_id` | If using GitHub App |
| `secrets.github_app_private_key` | If using GitHub App |
| `runners.maxRunners` | Max number of runner pods (default: 10) |
| `runners.minRunners` | Min number of runner pods (default: 1) |
| `runners.runnerGroup` | Runner group (must already exist in your GitHub org/enterprise; defaults to "default") |
| `runners.runnerScaleSetName` | Becomes the `runs-on` label in workflows; defaults to Helm release name |
| `controller.flags.watchSingleNamespace` | Restrict controller to a single namespace (recommended for security) |

## Step 2 - Option B - Deploy with ArgoCD
1. Prerequisite - IF ArgoCD doesn't have permissions to create CustomResourceDefinition(CRD):
- **ARC CRDs must be pre-installed by a cluster admin** (the chart's `crds/` directory contains them, but ArgoCD projects without cluster-scoped permissions cannot create CRDs):

  ```bash
  VERSION="0.14.2"  # match the controller dependency version in Chart.yaml
  BASE_URL="https://raw.githubusercontent.com/actions/actions-runner-controller/gha-runner-scale-set-${VERSION}/charts/gha-runner-scale-set-controller/crds"
  oc apply --server-side -f "${BASE_URL}/actions.github.com_autoscalinglisteners.yaml"
  oc apply --server-side -f "${BASE_URL}/actions.github.com_autoscalingrunnersets.yaml"
  oc apply --server-side -f "${BASE_URL}/actions.github.com_ephemeralrunners.yaml"
  oc apply --server-side -f "${BASE_URL}/actions.github.com_ephemeralrunnersets.yaml"
  ```
  > **Note:** `--server-side` is required because the ARC CRDs exceed the 256 KB annotation limit for client-side apply. When upgrading the controller version, update CRDs first by re-running the commands above with the new version.

2. Update [helm-arc-openshift/values.yaml](values.yaml)
   - **Tip:** Search for `#UPDATE THIS` in `values.yaml` to find all values that must be customized for your environment.

3. Apply / create ArgoCD Application - [helm-arc-openshift/argocd-app-reference.yaml](argocd-app-reference.yaml)
   - Update the project and namespace names.
   - Ensure `skipCrds: true` is set under `spec.source.helm` (CRDs must be installed separately — see [Prerequisites](#prerequisites)). **ONLY IF ARGOCD DOESNT HAVE PERMISSION TO CREATE CRD'S**
   - Update ignoreDifferences for name of Secret(Used for GitHub PAT or App credential) and ConfigMap (used for TLS Trusted Bundle)
4. Manually modify the values of Secret `arc-runner-secret` in OpenShift/Kubernetes
   - Use one of: PAT or GitHub App.
   - **Note:** The GitHub config URL is NOT stored in the Secret — it is set via `runners.githubConfigUrl` in values.yaml.
5. Deployment restart / old pod deletion to reflect Secret value changes.


## Use in workflows

```yaml
jobs:
  build:
    runs-on: arc-ocp   # matches the helm release name. Can also use the value of this if defined: runners.runnerScaleSetName
    steps:
      - uses: actions/checkout@v4
      - run: echo "Running on OpenShift via ARC!"
```

## OpenShift-specific details

| Issue | Solution |
|---|---|
| **SecurityContextConstraints** | The runner SA gets the `anyuid` SCC via a RoleBinding to the built-in ClusterRole `system:openshift:scc:anyuid`. The controller SA gets the `nonroot-v2` SCC via a namespace-scoped Role/RoleBinding. |
| **GHES TLS** | A ConfigMap annotated with `config.openshift.io/inject-trusted-cabundle` is created so OpenShift injects the cluster CA bundle. This is mounted into both the controller and runner/listener pods so they trust GHES. The env var `GITHUB_ACTIONS_FORCE_GHES=true` is set on the controller and listener to use the GHES API path. |
| **Arbitrary UID assignment** | The runner image sets `chown -R runner:0` and `chmod 775` so GID 0 (root group, assigned by OpenShift) has write access |
| **Cluster pull secrets** | If your cluster can't reach `ghcr.io`, mirror the controller image or set `imagePullSecrets` |

## Customizing

- Edit [values.yaml](values.yaml) for secrets, SA names, SCC settings, and sub-chart configuration
- Edit [container_image/Containerfile](../container_image/Containerfile) to change the runner version or add tools

## Cleanup

```bash
helm uninstall arc-ocp -n arc-systems
```
