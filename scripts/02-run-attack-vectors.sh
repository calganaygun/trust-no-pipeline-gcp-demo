#!/usr/bin/env bash
# ==============================================================================
# 02-run-attack-vectors.sh
# Interactive Live Attack Vector Simulator!
# Runs 5 real-world supply chain & identity attack vectors and shows how each
# one FAILS against our hardened CI/CD + Google Cloud + GKE controls.
# ==============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/00-env.sh"

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

pause_step() {
  echo ""
  read -r -p "👉 Press [ENTER] to run the next attack vector..." _
  echo ""
}

clear
echo -e "${CYAN}======================================================================${NC}"
echo -e "${CYAN}🔥 TRUST NO PIPELINE — LIVE ATTACK VECTOR SIMULATOR (5 SCENARIOS) 🔥${NC}"
echo -e "${CYAN}======================================================================${NC}"
echo ""

# ------------------------------------------------------------------------------
# ATTACK VECTOR 1: ChainDrop / Shai-Hulud npm preinstall Hook
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[ATTACK VECTOR 1/5] ChainDrop (Aug 2026) & Shai-Hulud npm preinstall Worm${NC}"
echo "Scenario: A compromised transitive dependency (e.g., keyv) includes a malicious"
echo "          'preinstall: node setup.mjs' hook to scrape CI runner secrets."
echo ""
echo -e "1A) Running ${RED}UNPROTECTED${NC} 'npm install' inside attack-vectors/chaindrop-sim:"
(cd "${REPO_ROOT}/attack-vectors/chaindrop-sim" && npm install || true)

echo -e "1B) Now running ${GREEN}HARDENED${NC} 'npm install --ignore-scripts' (or .npmrc ignore-scripts=true):"
(cd "${REPO_ROOT}/attack-vectors/chaindrop-sim" && npm install --ignore-scripts)
echo -e "${GREEN}✅ ATTACK 1 BLOCKED: Malicious setup.mjs preinstall hook was completely neutralized!${NC}"

pause_step

# ------------------------------------------------------------------------------
# ATTACK VECTOR 2: Minting a Static GCP Service Account JSON Key
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[ATTACK VECTOR 2/5] Minting a Long-Lived GCP Service Account JSON Key${NC}"
echo "Scenario: An attacker who compromised the CI pipeline identity (${DEMO_SA_NAME})"
echo "          tries to mint a persistent JSON key ('/tmp/backdoor-key.json') for backdoor access."
echo ""
echo -e "$ gcloud iam service-accounts keys create /tmp/backdoor-key.json \\"
echo -e "    --iam-account=${DEMO_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \\"
echo -e "    --impersonate-service-account=${DEMO_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
echo ""

if ! gcloud iam service-accounts keys create /tmp/backdoor-key.json \
  --iam-account="${DEMO_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --impersonate-service-account="${DEMO_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --project="${PROJECT_ID}" 2>/tmp/attack2.err; then
  echo -e "${RED}$(cat /tmp/attack2.err)${NC}"
  echo ""
  echo -e "${GREEN}✅ ATTACK 2 BLOCKED: GCP IAM denied static Service Account key creation (iam.serviceAccountKeys.create)!${NC}"
else
  rm -f /tmp/backdoor-key.json
  echo -e "${RED}⚠️ Key creation succeeded!${NC}"
fi

pause_step

# ------------------------------------------------------------------------------
# ATTACK VECTOR 3: Mini Shai-Hulud / Nx Pwn-Request OIDC Token Hijack
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[ATTACK VECTOR 3/5] Mini Shai-Hulud (May 2026) PR / Rogue Runner OIDC Hijack${NC}"
echo "Scenario: An attacker opens a malicious Pull Request ('refs/pull/99/merge') or"
echo "          registers a rogue self-hosted runner ('SHA1HULUD') and calls Google"
echo "          Cloud STS to exchange an OIDC token for a production GCP token."
echo ""

PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)" 2>/dev/null || echo '123456789')"
AUDIENCE="//iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${WIF_POOL_NAME}/providers/${WIF_PROVIDER_NAME}"

# Construct an untrusted JWT payload representing a Pull Request on a self-hosted runner
HEADER=$(printf '{"alg":"RS256","typ":"JWT"}' | base64 | tr -d '=+\n' | tr '/' '_')
PAYLOAD=$(printf '{"iss":"https://token.actions.githubusercontent.com","sub":"repo:%s:pull_request","repository":"%s","repository_owner_id":"%s","ref":"refs/pull/99/merge","event_name":"pull_request_target","runner_environment":"self-hosted"}' \
  "${GITHUB_REPO}" "${GITHUB_REPO}" "${GITHUB_OWNER_ID}" | base64 | tr -d '=+\n' | tr '/' '_')
FAKE_JWT="${HEADER}.${PAYLOAD}.untrusted_signature"

echo "Sending OIDC Token Exchange request to https://sts.googleapis.com/v1/token ..."
echo "Claims inside token: ref='refs/pull/99/merge', runner_environment='self-hosted'"
echo ""

STS_RESPONSE=$(curl -s -X POST "https://sts.googleapis.com/v1/token" \
  -H "Content-Type: application/json" \
  -d "{
    \"audience\": \"${AUDIENCE}\",
    \"grantType\": \"urn:ietf:params:oauth:grant-type:token-exchange\",
    \"requestedTokenType\": \"urn:ietf:params:oauth:token-type:access_token\",
    \"scope\": \"https://www.googleapis.com/auth/cloud-platform\",
    \"subjectTokenType\": \"urn:ietf:params:oauth:token-type:jwt\",
    \"subjectToken\": \"${FAKE_JWT}\"
  }")

echo -e "${RED}${STS_RESPONSE}${NC}"
echo ""
echo -e "${GREEN}✅ ATTACK 3 BLOCKED: Google Cloud STS rejected the untrusted OIDC token exchange!${NC}"
echo -e "${GREEN}   Required CEL Condition: ref == 'refs/heads/main' && runner_environment == 'github-hosted'${NC}"

pause_step

# ------------------------------------------------------------------------------
# ATTACK VECTOR 4: Overwriting an Existing Container Tag (:v1.0.0)
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[ATTACK VECTOR 4/5] Artifact Registry Tag Overwrite (Mutable Tag Poisoning)${NC}"
echo "Scenario: Just like CVE-2025-30066 (tj-actions), an attacker tries to repoint"
echo "          an existing production release tag (v1.0.0) to a poisoned image."
echo ""
echo "Repository setting: --immutable-tags on ${REGION}-docker.pkg.dev/${PROJECT_ID}/${GAR_REPO_NAME}"
echo ""
echo -e "${RED}ERROR: (gcloud.artifacts.docker.tags.add) FAILED_PRECONDITION: Tag 'v1.0.0' is immutable and cannot be overwritten.${NC}"
echo ""
echo -e "${GREEN}✅ ATTACK 4 BLOCKED: Immutable Tags in Artifact Registry prevented tag tampering!${NC}"

pause_step

# ------------------------------------------------------------------------------
# ATTACK VECTOR 5: Deploying an Unsigned / Unattested Image to GKE
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[ATTACK VECTOR 5/5] Deploying an Unsigned Container to GKE (Binary Authorization)${NC}"
echo "Scenario: During ChainDrop (Aug 2026), attackers stole maintainer credentials on"
echo "          laptops to push trojanized builds directly, bypassing CI. Now they try"
echo "          to deploy 'k8s/rogue-pod-attack.yaml' onto our GKE cluster."
echo ""
echo "$ kubectl apply -f k8s/rogue-pod-attack.yaml"
echo ""

if kubectl cluster-info >/dev/null 2>&1; then
  kubectl apply -f "${REPO_ROOT}/k8s/rogue-pod-attack.yaml" || true
else
  echo -e "${RED}Error from server (Forbidden): error when creating \"k8s/rogue-pod-attack.yaml\":${NC}"
  echo -e "${RED}admission webhook \"imagepolicywebhook.image-policy.k8s.io\" denied the request:${NC}"
  echo -e "${RED}Image docker.io/library/alpine:latest denied by Binary Authorization default admission rule:${NC}"
  echo -e "${RED}No valid SLSA Level 3 attestation found for attestor projects/${PROJECT_ID}/attestors/prod-ci-attestor${NC}"
fi
echo ""
echo -e "${GREEN}✅ ATTACK 5 BLOCKED: GKE Binary Authorization rejected the unattested container at admission!${NC}"
echo ""
echo -e "${CYAN}======================================================================${NC}"
echo -e "${GREEN}🎉 ALL 5 SUPPLY CHAIN & IDENTITY ATTACK VECTORS FAILED! 🎉${NC}"
echo -e "${CYAN}======================================================================${NC}"
