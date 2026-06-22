# Utilities

Helper scripts for managing GitHub Actions self-hosted runner infrastructure.

## gh-runnergroup-mgr.sh

A CLI tool to **add or remove repositories** from a GitHub Enterprise runner group using a GitHub App for authentication.

### Prerequisites

- `bash`, `curl`, `openssl`, `jq`
- A [GitHub App](https://docs.github.com/en/apps/creating-github-apps/about-creating-github-apps/about-creating-github-apps) with the following permissions:
  - **Organization → Self-hosted runners:** Read and write
  - **Repository → Metadata:** Read-only

### Usage

```bash
./gh-runnergroup-mgr.sh [OPTIONS]
```

| Option | Description | Required |
|---|---|---|
| `-h`, `--host <host>` | GitHub Enterprise hostname (default: `github.com`) | No |
| `-a`, `--app-id <id>` | GitHub App ID | Yes |
| `-k`, `--key <path>` | Path to the GitHub App private key `.pem` file | Yes |
| `-o`, `--org <org>` | GitHub Organization name | Yes |
| `-g`, `--group <name>` | Target Runner Group name | Yes |
| `-r`, `--repo <name>` | Target Repository name | Yes |
| `--action <add\|remove>` | Action to perform | Yes |

### Example

```bash
./gh-runnergroup-mgr.sh \
  --host github.com \
  --app-id 12345 \
  --key ./my-app.pem \
  --org my-org \
  --group my-runner-group \
  --repo my-repo \
  --action add
```

### Example Output:
```
$ ./gh-runnergroup-mgr.sh --host github.com --app-id 12345 --key ./my-app.pem --org my-org --group my-runner-group --repo my-sample-repo --action add
[+] Generating JSON Web Token (JWT)...
[+] Retrieving App Installation ID for organization: my-org...
[+] Requesting Installation Access Token...
[+] Looking up Runner Group ID for 'my-runner-group'...
[+] Found Runner Group ID: 25
[+] Looking up Repository ID for 'my-sample-repo'...
[+] Found Repository ID: 1368646
[+] Adding repository 'my-sample-repo' to runner group 'my-runner-group'...
[+] Success! Repository my-sample-repo has been added.
This is a list of repos in the runner group: my-runner-group
{
  "total_count": 2,
  "repositories": [
    {
      "html_url": "https://github.com/my-org/github-self-hosted-runner"
    },
    {
      "html_url": "https://github.com/my-org/my-sample-repo"
    }
  ]
}
```

### How It Works

1. Generates a JWT from the GitHub App credentials.
2. Retrieves the App's installation ID for the target organization.
3. Requests an Installation Access Token.
4. Looks up the Runner Group ID by name.
5. Looks up the Repository ID by name.
6. Adds or removes the repository from the runner group via the GitHub API.
