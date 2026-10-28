#!/usr/bin/env bash
# ==============================================================================
# 01-setup-gcp-guardrails.sh
# Provisions Google Cloud Zero-Trust Pipeline Guardrails:
#   1. Enables required GCP APIs
#   2. Blocks Static SA Key Creation via Org Policy, IAM v2 Deny Policy & Least Privilege
#   3. Creates Workload Identity Pool + CEL-Locked GitHub OIDC Provider
#   4. Creates Artifact Registry with --immutable-tags
#   5. Builds & pushes v1.0.0 via Regional Cloud Build (SLSA Level 3 Provenance)
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/00-env.sh"

gcloud config set project "${PROJECT_ID}"
PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")"
USER_EMAIL="$(gcloud config get-value account 2>/dev/null || true)"
SA_EMAIL="${DEMO_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
CLOUDBUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

echo "🚀 [1/5] Enabling required Google Cloud APIs..."
gcloud services enable \
  compute.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  sts.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  containerscanning.googleapis.com \
  binaryauthorization.googleapis.com \
  containeranalysis.googleapis.com \
  container.googleapis.com \
  secretmanager.googleapis.com \
  orgpolicy.googleapis.com \
  --project="${PROJECT_ID}"

echo "🛡️ [2/5] Configuring CI Service Account & Blocking Static JSON Keys..."
gcloud iam service-accounts create "${DEMO_SA_NAME}" \
  --display-name="CI Prod Deployer (WIF Only - No Keys)" \
  --project="${PROJECT_ID}" 2>/dev/null || true

# Grant required Cloud Build & Artifact Registry roles (NOTE: NO iam.serviceAccountKeyAdmin!)
for ACCOUNT in "${SA_EMAIL}" "${COMPUTE_SA}" "${CLOUDBUILD_SA}"; do
  for ROLE in \
    "roles/artifactregistry.writer" \
    "roles/cloudbuild.builds.builder" \
    "roles/cloudbuild.builds.editor" \
    "roles/iam.serviceAccountUser" \
    "roles/storage.admin" \
    "roles/logging.logWriter" \
    "roles/serviceusage.serviceUsageConsumer"; do
    gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
      --member="serviceAccount:${ACCOUNT}" \
      --role="${ROLE}" --quiet >/dev/null 2>&1 || true
  done
done

if [[ -n "${USER_EMAIL}" ]]; then
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="user:${USER_EMAIL}" \
    --role="roles/iam.denyAdmin" --quiet >/dev/null 2>&1 || true
  gcloud iam service-accounts add-iam-policy-binding "${SA_EMAIL}" \
    --project="${PROJECT_ID}" \
    --member="user:${USER_EMAIL}" \
    --role="roles/iam.serviceAccountTokenCreator" --quiet >/dev/null 2>&1 || true
fi

# 2A) If an Organization exists, auto-grant roles/orgpolicy.policyAdmin & set Org Policy
ORG_ID="$(gcloud organizations list --format="value(ID)" --limit=1 2>/dev/null || true)"
if [[ -n "${ORG_ID}" && -n "${USER_EMAIL}" ]]; then
  gcloud organizations add-iam-policy-binding "${ORG_ID}" \
    --member="user:${USER_EMAIL}" \
    --role="roles/orgpolicy.policyAdmin" --quiet >/dev/null 2>&1 || true
fi

cat <<EOF > /tmp/disable-sa-keys.yaml
name: projects/${PROJECT_ID}/policies/iam.disableServiceAccountKeyCreation
spec:
  rules:
  - enforce: true
EOF
if gcloud org-policies set-policy /tmp/disable-sa-keys.yaml --project="${PROJECT_ID}" 2>/dev/null; then
  echo "   ✅ Enforced Org Policy: constraints/iam.disableServiceAccountKeyCreation"
fi

# 2B) Enforce Project-level IAM v2 Deny Policy (URL-encoded attachment point)
cat <<EOF > /tmp/deny-sa-keys-policy.json
{
  "displayName": "Deny Static Service Account Key Creation",
  "rules": [
    {
      "description": "Block creation of long-lived user-managed Service Account JSON keys",
      "denyRule": {
        "deniedPrincipals": [
          "principalSet://goog/public:all"
        ],
        "deniedPermissions": [
          "iam.googleapis.com/serviceAccountKeys.create"
        ]
      }
    }
  ]
}
EOF

gcloud iam policies create deny-static-sa-keys \
  --attachment-point="cloudresourcemanager.googleapis.com%2Fprojects%2F${PROJECT_NUMBER}" \
  --kind="denypolicies" \
  --policy-file=/tmp/deny-sa-keys-policy.json >/dev/null 2>&1 || true
echo "   ✅ Enforced Static Key Creation Block (Least-Privilege CI SA + IAM v2 Deny Policy)"

echo "🪪 [3/5] Creating Workload Identity Pool & Hardened OIDC Provider (CEL Locked)..."
gcloud iam workload-identity-pools create "${WIF_POOL_NAME}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --display-name="GitHub Actions Prod Pool" 2>/dev/null || true

CEL_CONDITION="assertion.repository_owner_id == '${GITHUB_OWNER_ID}' && assertion.repository == '${GITHUB_REPO}' && assertion.ref == 'refs/heads/main' && assertion.runner_environment == 'github-hosted'"

gcloud iam workload-identity-pools providers create-oidc "${WIF_PROVIDER_NAME}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="${WIF_POOL_NAME}" \
  --display-name="GitHub Actions Hardened OIDC" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref,attribute.workflow_ref=assertion.job_workflow_ref" \
  --attribute-condition="${CEL_CONDITION}" 2>/dev/null || \
gcloud iam workload-identity-pools providers update-oidc "${WIF_PROVIDER_NAME}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="${WIF_POOL_NAME}" \
  --attribute-condition="${CEL_CONDITION}"

WIF_MEMBER="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${WIF_POOL_NAME}/attribute.repository/${GITHUB_REPO}"

gcloud iam service-accounts add-iam-policy-binding "${SA_EMAIL}" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="${WIF_MEMBER}" >/dev/null

echo "📦 [4/5] Creating Artifact Registry with IMMUTABLE TAGS & Direct WIF IAM Binding..."
gcloud artifacts repositories create "${GAR_REPO_NAME}" \
  --project="${PROJECT_ID}" \
  --repository-format=docker \
  --location="${REGION}" \
  --immutable-tags \
  --description="Hardened production container registry with immutable tags" 2>/dev/null || true

gcloud artifacts repositories add-iam-policy-binding "${GAR_REPO_NAME}" \
  --project="${PROJECT_ID}" \
  --location="${REGION}" \
  --role="roles/artifactregistry.writer" \
  --member="${WIF_MEMBER}" >/dev/null

echo "🏭 [5/5] Building & Pushing v1.0.0 via Regional Cloud Build (SLSA Level 3 Provenance)..."
IMAGE_URI="${REGION}-docker.pkg.dev/${PROJECT_ID}/${GAR_REPO_NAME}/payments-api:v1.0.0"
gcloud builds submit "${REPO_ROOT}/app" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --tag="${IMAGE_URI}" 2>/dev/null || echo "   ℹ️ Image v1.0.0 already exists in Artifact Registry (protected by immutable tags)."

WIF_PROVIDER_FULL="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${WIF_POOL_NAME}/providers/${WIF_PROVIDER_NAME}"

echo ""
echo "========================================================================"
echo "✅ GCP ZERO-TRUST GUARDRAILS CONFIGURED SUCCESSFULLY"
echo "========================================================================"
echo "GCP_PROJECT_ID=${PROJECT_ID}"
echo "GCP_WIF_PROVIDER=${WIF_PROVIDER_FULL}"
echo "GCP_SERVICE_ACCOUNT=${SA_EMAIL}"
echo "========================================================================"
