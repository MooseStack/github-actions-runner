# github-actions-runner

## Build and push Image
1. `podman build -t runner ./container_image/`
2. `podman tag runner:latest docker.io/moosestack/github-actions-runner:latest`
3. `podman push docker.io/moosestack/github-actions-runner:latest`

Image storaged in [Dockerhub](https://hub.docker.com/r/moosestack/github-actions-runner/tags)


## Deploy with Helm
1. Edit [helm/values.yaml](helm/values.yaml) with your requirements

2. To install the chart:

```
   helm install gh-runner ./helm -n gh-runner \
   --create-namespace \
   --values ./helm/values.yaml \
   --set secrets.GITHUB_PAT='YOUR_GH_PAT'
```

3. This chart creates:
    1. Deployment - pods containing the GitHub Runner on a UBI image
    2. Secret - Runner configurations that get used as Environment variables to Deployment pods
    3. ServiceAccount and Role/RoleBinding scoped to the release namespace which grant access to Tekton resources (pipelineruns, taskruns, pipelines, tasks) and related core resources (pods, secrets, serviceaccounts, configmaps).