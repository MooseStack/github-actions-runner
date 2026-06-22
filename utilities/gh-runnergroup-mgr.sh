#!/usr/bin/env bash

set -euo pipefail

# Default values
GHE_HOST="github.com"
APP_ID=""
PRIVATE_KEY_PATH=""
ORG=""
RUNNER_GROUP_NAME=""
REPO_NAME=""
ACTION=""

# --- Usage/Help Menu ---
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

A CLI tool to add or remove repositories from a GitHub Enterprise runner group using a GitHub App.

Options:
  -h, --host <host>       GHE Hostname (e.g., github.yourcompany.com). Defaults to 'github.com'.
  -a, --app-id <id>       GitHub App ID (Required)
  -k, --key <path>        Path to the GitHub App private key .pem file (Required)
  -o, --org <org>         GitHub Organization name (Required)
  -g, --group <name>      Target Runner Group name (Required)
  -r, --repo <name>       Target Repository name (Required)
  --action <add|remove>   Action to perform: 'add' or 'remove' (Required)
  --help                  Show this help message and exit

Example:
  ./gh-runnergroup-mgr.sh --host github.com --app-id 12345 --key ./my-app.pem --org my-org --group my-runner-group --repo github-self-hosted-runner --action add

EOF
    exit 1
}

# --- Parse Arguments ---
if [[ $# -eq 0 ]]; then usage; fi
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--host) GHE_HOST="$2"; shift 2 ;;
        -a|--app-id) APP_ID="$2"; shift 2 ;;
        -k|--key) PRIVATE_KEY_PATH="$2"; shift 2 ;;
        -o|--org) ORG="$2"; shift 2 ;;
        -g|--group) RUNNER_GROUP_NAME="$2"; shift 2 ;;
        -r|--repo) REPO_NAME="$2"; shift 2 ;;
        --action) ACTION="$2"; shift 2 ;;
        --help) usage ;;
        *) echo "[-] Error: Unknown option '$1'"; usage ;;
    esac
done

# --- Validation ---
if [[ -z "$APP_ID" || -z "$PRIVATE_KEY_PATH" || -z "$ORG" || -z "$RUNNER_GROUP_NAME" || -z "$REPO_NAME" || -z "$ACTION" ]]; then
    echo "[-] Error: Missing required arguments."
    usage
fi
if [[ "$ACTION" != "add" && "$ACTION" != "remove" ]]; then
    echo "[-] Error: --action must be either 'add' or 'remove'."
    exit 1
fi
if [[ ! -f "$PRIVATE_KEY_PATH" ]]; then
    echo "[-] Error: Private key file not found at: $PRIVATE_KEY_PATH"
    exit 1
fi

# --- Determine API Base URL ---
if [[ "$GHE_HOST" == "github.com" ]]; then
    API_URL="https://api.github.com"
else
    API_URL="https://${GHE_HOST}/api/v3"
fi

b64enc() { openssl base64 -e -A | tr -d '=' | tr '/+' '_-'; }

# --- Step 1: Generate GitHub App JWT ---
echo "[+] Generating JSON Web Token (JWT)..."
header=$(echo -n '{"alg":"RS256","typ":"JWT"}' | b64enc)
now=$(date +%s)
iat=$((now - 60))  
exp=$((now + 540)) 
payload=$(echo -n "{\"iat\":$iat,\"exp\":$exp,\"iss\":\"$APP_ID\"}" | b64enc)
signature=$(echo -n "$header.$payload" | openssl dgst -sha256 -sign "$PRIVATE_KEY_PATH" | b64enc)
JWT="$header.$payload.$signature"

# --- Step 2: Fetch Installation ID ---
echo "[+] Retrieving App Installation ID for organization: $ORG..."
INST_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "Authorization: Bearer $JWT" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "$API_URL/orgs/$ORG/installation")

INST_STATUS=$(echo "$INST_RESPONSE" | tail -n1)
INST_BODY=$(echo "$INST_RESPONSE" | sed '$d')

if [ "$INST_STATUS" -ne 200 ]; then
    echo "[-] Failed to fetch installation ID (HTTP $INST_STATUS)."
    echo "[-] API Response: $INST_BODY"
    exit 1
fi
INSTALLATION_ID=$(echo "$INST_BODY" | jq -r '.id')

# --- Step 3: Fetch Installation Access Token (IAT) ---
echo "[+] Requesting Installation Access Token..."
TOKEN_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer $JWT" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "$API_URL/app/installations/$INSTALLATION_ID/access_tokens")

TOKEN_STATUS=$(echo "$TOKEN_RESPONSE" | tail -n1)
TOKEN_BODY=$(echo "$TOKEN_RESPONSE" | sed '$d')

if [ "$TOKEN_STATUS" -ne 201 ]; then
    echo "[-] Failed to generate token (HTTP $TOKEN_STATUS)."
    echo "[-] API Response: $TOKEN_BODY"
    exit 1
fi
TOKEN=$(echo "$TOKEN_BODY" | jq -r '.token')

# --- Step 4: Look up Runner Group ID (With Safe Check) ---
echo "[+] Looking up Runner Group ID for '$RUNNER_GROUP_NAME'..."
RG_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "$API_URL/orgs/$ORG/actions/runner-groups?per_page=100")

RG_STATUS=$(echo "$RG_RESPONSE" | tail -n1)
RG_BODY=$(echo "$RG_RESPONSE" | sed '$d')

if [ "$RG_STATUS" -ne 200 ]; then
    echo "[-] Error: Failed to list runner groups (HTTP $RG_STATUS)."
    echo "[-] API Response: $RG_BODY"
    echo "[-] HINT: Check your GitHub App's Organization permissions for 'Self-hosted runners'."
    exit 1
fi

RUNNER_GROUP_ID=$(echo "$RG_BODY" | jq -r --arg name "$RUNNER_GROUP_NAME" '.runner_groups[] | select(.name == $name) | .id')

if [[ -z "$RUNNER_GROUP_ID" || "$RUNNER_GROUP_ID" == "null" ]]; then
    echo "[-] Error: Runner group '$RUNNER_GROUP_NAME' not found."
    exit 1
fi
echo "[+] Found Runner Group ID: $RUNNER_GROUP_ID"

# --- Step 5: Look up Repository ID (With Safe Check) ---
echo "[+] Looking up Repository ID for '$REPO_NAME'..."
REPO_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "$API_URL/repos/$ORG/$REPO_NAME")

REPO_STATUS=$(echo "$REPO_RESPONSE" | tail -n1)
REPO_BODY=$(echo "$REPO_RESPONSE" | sed '$d')

if [ "$REPO_STATUS" -ne 200 ]; then
    echo "[-] Error: Failed to find repository '$REPO_NAME' (HTTP $REPO_STATUS)."
    echo "[-] API Response: $REPO_BODY"
    echo "[-] HINT: Verify the repository name or check your App's Repository 'Metadata' permissions."
    exit 1
fi
REPO_ID=$(echo "$REPO_BODY" | jq -r '.id')
echo "[+] Found Repository ID: $REPO_ID"

# --- Step 6: Modify Runner Group Repository Access ---
ENDPOINT="$API_URL/orgs/$ORG/actions/runner-groups/$RUNNER_GROUP_ID/repositories/$REPO_ID"

if [[ "$ACTION" == "add" ]]; then
    echo "[+] Adding repository '$REPO_NAME' to runner group '$RUNNER_GROUP_NAME'..."
    ACTION_RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "$ENDPOINT")
else
    echo "[+] Removing repository '$REPO_NAME' from runner group '$RUNNER_GROUP_NAME'..."
    ACTION_RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "$ENDPOINT")
fi

ACTION_STATUS=$(echo "$ACTION_RESPONSE" | tail -n1)

if [ "$ACTION_STATUS" -eq 204 ]; then
    echo "[+] Success! Repository $REPO_NAME has been ${ACTION}ed."
    echo "This is a list of repos in the runner group: $RUNNER_GROUP_NAME"
    curl -s -L \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $TOKEN" \
        -H "X-GitHub-Api-Version: 2026-03-10" \
        $API_URL/orgs/$ORG/actions/runner-groups/$RUNNER_GROUP_ID/repositories | \
        jq '{total_count: .total_count, repositories: [.repositories[] | {html_url: .html_url}]}'
else
    echo "[-] Action failed (HTTP STATUS $ACTION_STATUS)."
    echo "[-] API Response: $(echo "$ACTION_RESPONSE" | sed '$d')"
    exit 1
fi