#!/usr/bin/env bash
# ==============================================================================
# 00-env.sh — Shared Environment Configuration (Cloud Shell Ready!)
# ==============================================================================
set -euo pipefail

# Cloud Shell automatically sets GOOGLE_CLOUD_PROJECT or DEVSHELL_PROJECT_ID
export PROJECT_ID="${PROJECT_ID:-${GOOGLE_CLOUD_PROJECT:-${DEVSHELL_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || echo 'trustnopipelines')}}}"
export REGION="${REGION:-us-central1}"
export CLUSTER_NAME="${CLUSTER_NAME:-prod-gke-cluster}"

# GitHub Repository & Immutable Numeric Owner ID (calganaygun = 20268300)
export GITHUB_OWNER="${GITHUB_OWNER:-calganaygun}"
export GITHUB_REPO="${GITHUB_REPO:-${GITHUB_OWNER}/trust-no-pipeline-gcp-demo}"
export GITHUB_OWNER_ID="${GITHUB_OWNER_ID:-20268300}"

# Workload Identity Pool & Provider Names
export WIF_POOL_NAME="github-prod-pool"
export WIF_PROVIDER_NAME="github-oidc-provider"
export GAR_REPO_NAME="prod-containers"
export DEMO_SA_NAME="ci-prod-deployer"

echo "--------------------------------------------------------"
echo "🔧 Loaded Demo Environment:"
echo "   GCP Project ID : ${PROJECT_ID}"
echo "   GCP Region     : ${REGION}"
echo "   GitHub Repo    : ${GITHUB_REPO} (Owner ID: ${GITHUB_OWNER_ID})"
echo "--------------------------------------------------------"
