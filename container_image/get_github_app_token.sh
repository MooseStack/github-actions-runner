#!/bin/bash

get_github_app_token() {
        NOW=$( date +%s )
        IAT=$((${NOW}  - 60))
        EXP=$((${NOW} + 540))
        HEADER_RAW='{"alg":"RS256"}'
        HEADER=$( echo -n "${HEADER_RAW}" | openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n' )
        PAYLOAD_RAW='{"iat":'"${IAT}"',"exp":'"${EXP}"',"iss":'"${GITHUB_APP_ID}"'}'
        PAYLOAD=$( echo -n "${PAYLOAD_RAW}" | openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n' )
        HEADER_PAYLOAD="${HEADER}"."${PAYLOAD}"

        SIGNATURE=$( openssl dgst -sha256 -sign <(printf '%s' "$GITHUB_APP_PEM") <(printf '%s' "$HEADER_PAYLOAD") | openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n' )

        JWT="${HEADER_PAYLOAD}"."${SIGNATURE}"
        INSTALL_URL="https://${GITHUB_API_SERVER}/app/installations/${GITHUB_APP_INSTALL_ID}/access_tokens"
        INSTALL_TOKEN_PAYLOAD=$(curl -sSfLkX POST -H "Authorization: Bearer ${JWT}" -H "Accept: application/vnd.github.v3+json" "${INSTALL_URL}")
        INSTALL_TOKEN=$(echo ${INSTALL_TOKEN_PAYLOAD} | jq .token --raw-output)
        
        echo "${INSTALL_TOKEN}"
}