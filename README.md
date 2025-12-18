# Build and push Image
1. `podman build -t runner ./container_image/`
2. `podman tag runner:latest docker.io/moosestack/github-actions-runner:latest`
3. `podman push docker.io/moosestack/github-actions-runner:latest`

Image uploaded to [Dockerhub](https://hub.docker.com/r/moosestack/github-actions-runner/tags)


# Deploy:

## 1 - Deploy with [helm](https://helm.sh/docs/intro/install/) cli
1. Edit [helm/values.yaml](helm/values.yaml) with your requirements

2. To install the chart:

```
   helm install gh-runner ./helm -n gh-runner \
   --create-namespace \
   --values ./helm/values.yaml \
   --set secrets.GITHUB_PAT='YOUR_GH_PAT'
```

Other available options:

```
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
    --set secrets.GITHUB_OWNER="MooseStack"
    --set secrets.GITHUB_REPOSITORY="github-actions-runner"

# Runner workload directory
    --set secrets.GITHUB_RUNNER_WORKDIR="/opt/gh-actions-runner/_work"
    --set secrets.GITHUB_RUNNER_LABEL="ubi9-gh-runner,openshift"
    --set secrets.GITHUB_RUNNER_EPHEMERAL="" # options are "true" or empty ""
```

3. This chart creates:
    1. Deployment - pods containing the GitHub Runner on a UBI image
    2. Secret - Runner configurations that get used as Environment variables to Deployment pods
    3. ServiceAccount and Role/RoleBinding scoped to the release namespace which grant access to Tekton resources (pipelineruns, taskruns, pipelines, tasks) and related core resources (pods, secrets, serviceaccounts, configmaps).

## 2 - Deploy with ArgoCD

1. Modify the namespace, project name, etc in: [argocd](argocd)
2. `Kubectl apply -f ./argocd` or `oc apply -f ./argocd`
3. Manually update the values of the secret `github-actions-runner-secret` in openshift/kubernetes. Then do a Deployment restart. 