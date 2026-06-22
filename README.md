# GitHub Self Hosted Runner

## Repository Structure

```
├── container_image/                # Runner container images
│   ├── Containerfile               # Shared base image (UBI9 + runner + tools)
│   ├── Containerfile.traditional   # Traditional runner layer (entrypoint + registration)
│   ├── Containerfile.arc           # ARC runner layer (container hooks + run.sh)
│   ├── entrypoint.sh               # Traditional runner entrypoint
│   ├── get_github_app_token.sh     # GitHub App JWT token helper
│   ├── register.sh                 # Runner registration script
│   └── etc-containers-storage.conf # Podman/Buildah storage config
├── helm-traditional/               # Helm chart — traditional runner (Deployment)
├── helm-arc-openshift/             # Helm chart — ARC runner (autoscaling ephemeral)
└── .github/workflows/              # CI pipelines for image builds
    ├── traditional-image.yaml
    └── arc-image.yaml
```

# Deploy:

## Prerequisite - Create GitHub Credentials

You can use a [Personal Access Token(PAT)](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token), [GitHub App](https://docs.github.com/en/apps/creating-github-apps/about-creating-github-apps/about-creating-github-apps), or a Runner Token(ephemural).

### [Personal Access Token(PAT)](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)

Permissions needed:
1. `Actions: Read and write`
2. `Contents: Read-only`
3. `Metdadata: Read-only`
4. `Workflows: Read and write`
5. `Administration: Read and write` for individual repositories, OR `organization_self_hosted_runners: Read and write` if organization/owner wide runner.
   - This last one is used to generate ephemural Runner Tokens and adds/deletes/updates the Runner in GitHub.

## Option #1 — Traditional Runner (Deployment)

A **traditional runner** is a persistent, long-lived self-hosted runner deployed as a standard Kubernetes Deployment. The runner pod registers itself with GitHub on startup, picks up workflow jobs, and stays running between jobs. This approach is straightforward to set up and works well for steady workloads where you want a fixed number of runners always available.

- **Lifecycle:** Persistent — the runner pod stays running and processes multiple jobs sequentially.
- **Scaling:** Manual — you control the replica count in the Deployment.
- **Best for:** Stable workloads, simpler setups, or environments where autoscaling is not needed.

See **[helm-traditional/README.md](helm-traditional/README.md)** for image build and deploy instructions.

## Option #2 — ARC (Actions Runner Controller) on OpenShift

**ARC** is the GitHub-supported [Actions Runner Controller](https://github.com/actions/actions-runner-controller), which manages ephemeral runner pods that scale automatically based on workflow demand. A controller watches for queued jobs via the GitHub Actions API and spins up short-lived runner pods on demand. Each pod handles a single job and is destroyed afterward, providing a clean environment every time.

- **Lifecycle:** Ephemeral — each runner pod is created for one job and removed after completion.
- **Scaling:** Automatic — scales from zero to your configured maximum based on queued jobs.
- **Best for:** Variable or bursty workloads, cost efficiency, and environments that benefit from clean runner state per job.

See **[helm-arc-openshift/README.md](helm-arc-openshift/README.md)** for image build and deploy instructions.
